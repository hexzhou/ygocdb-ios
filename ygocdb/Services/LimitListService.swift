//
//  LimitListService.swift
//  ygocdb
//

import Foundation
import os.log

/// ygocdb 禁限卡表 API 服务。
actor LimitListService {
    static let shared = LimitListService()

    private struct CacheMetadata: Codable {
        var etag: String?
        var lastModified: String?
        var lastCheckedAt: Date
    }

    private static let defaultAPIURL = URL(string: "https://ygocdb.com/api/v0/limits.json?show=all")!
    private static let defaultRefreshInterval: TimeInterval = 24 * 60 * 60

    private let apiURL: URL
    private let session: URLSession
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let refreshInterval: TimeInterval
    private let now: () -> Date
    private let logger = Logger(subsystem: "com.ygocdb", category: "LimitListService")
    private var cachedResponse: LimitListResponse?
    private var cacheMetadata: CacheMetadata?
    private var didLoadDiskCache = false
    private var inFlightTask: Task<LimitListResponse, Error>?

    init(
        apiURL: URL = LimitListService.defaultAPIURL,
        session: URLSession = NetworkConfig.shared,
        cacheDirectory: URL? = nil,
        refreshInterval: TimeInterval = LimitListService.defaultRefreshInterval,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.apiURL = apiURL
        self.session = session
        self.fileManager = fileManager
        self.cacheDirectory = cacheDirectory
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LimitLists", isDirectory: true)
        self.refreshInterval = refreshInterval
        self.now = now
    }

    /// 返回内存或磁盘中的上次成功结果，不发起网络请求。
    func cachedLimitLists() -> LimitListResponse? {
        loadDiskCacheIfNeeded()
        return cachedResponse
    }

    func fetchLimitLists(forceRefresh: Bool = false) async throws -> LimitListResponse {
        loadDiskCacheIfNeeded()

        if !forceRefresh, let cachedResponse, isCacheFresh {
            return cachedResponse
        }

        if let inFlightTask {
            return try await inFlightTask.value
        }

        let task = Task { try await self.fetchFromNetwork() }
        inFlightTask = task

        do {
            let result = try await task.value
            inFlightTask = nil
            return result
        } catch {
            inFlightTask = nil
            if !forceRefresh, let cachedResponse {
                cacheMetadata = CacheMetadata(
                    etag: cacheMetadata?.etag,
                    lastModified: cacheMetadata?.lastModified,
                    lastCheckedAt: now()
                )
                persistMetadata()
                logger.info("禁限卡表后台更新失败，继续使用本地缓存")
                return cachedResponse
            }
            throw error
        }
    }

    private var isCacheFresh: Bool {
        guard let lastCheckedAt = cacheMetadata?.lastCheckedAt else { return false }
        return now().timeIntervalSince(lastCheckedAt) < refreshInterval
    }

    private func fetchFromNetwork() async throws -> LimitListResponse {
        var request = URLRequest(url: apiURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if cachedResponse != nil {
            if let etag = cacheMetadata?.etag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastModified = cacheMetadata?.lastModified {
                request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
            }
        }

        logger.info("正在更新禁限卡表: \(self.apiURL.absoluteString)")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LimitListError.invalidResponse
        }

        if httpResponse.statusCode == 304, let cachedResponse {
            cacheMetadata = CacheMetadata(
                etag: httpResponse.value(forHTTPHeaderField: "ETag") ?? cacheMetadata?.etag,
                lastModified: httpResponse.value(forHTTPHeaderField: "Last-Modified") ?? cacheMetadata?.lastModified,
                lastCheckedAt: now()
            )
            persistMetadata()
            logger.info("禁限卡表未更新，继续使用本地缓存")
            return cachedResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("禁限卡表 HTTP 错误: \(httpResponse.statusCode)")
            throw LimitListError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let result = try JSONDecoder().decode(LimitListResponse.self, from: data)
            cachedResponse = result
            cacheMetadata = CacheMetadata(
                etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse.value(forHTTPHeaderField: "Last-Modified"),
                lastCheckedAt: now()
            )
            persist(data: data)
            logger.info("禁限卡表加载完成")
            return result
        } catch {
            logger.error("禁限卡表解析失败: \(error.localizedDescription)")
            throw LimitListError.decodingFailed
        }
    }

    private var dataCacheURL: URL {
        cacheDirectory.appendingPathComponent("limits-all.json")
    }

    private var metadataCacheURL: URL {
        cacheDirectory.appendingPathComponent("metadata.json")
    }

    private func loadDiskCacheIfNeeded() {
        guard !didLoadDiskCache else { return }
        didLoadDiskCache = true

        if let data = try? Data(contentsOf: dataCacheURL),
           let response = try? JSONDecoder().decode(LimitListResponse.self, from: data) {
            cachedResponse = response
            logger.info("已载入本地禁限卡表缓存")
        }

        if let data = try? Data(contentsOf: metadataCacheURL),
           let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: data) {
            cacheMetadata = metadata
        }
    }

    private func persist(data: Data) {
        do {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: dataCacheURL, options: .atomic)
            persistMetadata()
        } catch {
            logger.error("禁限卡表缓存写入失败: \(error.localizedDescription)")
        }
    }

    private func persistMetadata() {
        guard let cacheMetadata else { return }

        do {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(cacheMetadata)
            try data.write(to: metadataCacheURL, options: .atomic)
        } catch {
            logger.error("禁限卡表缓存元数据写入失败: \(error.localizedDescription)")
        }
    }

    func clearCache() {
        inFlightTask?.cancel()
        inFlightTask = nil
        cachedResponse = nil
        cacheMetadata = nil
        didLoadDiskCache = true
        try? fileManager.removeItem(at: dataCacheURL)
        try? fileManager.removeItem(at: metadataCacheURL)
    }
}

enum LimitListError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "禁限卡表地址无效"
        case .invalidResponse:
            return "服务器返回了无效响应"
        case .requestFailed(let statusCode):
            return "禁限卡表请求失败（HTTP \(statusCode)）"
        case .decodingFailed:
            return "无法解析禁限卡表数据"
        }
    }
}
