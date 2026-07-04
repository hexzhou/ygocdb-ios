//
//  CardIDChangelogService.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/9.
//

import Foundation
import os.log

/// 卡片 ID 变更记录服务
actor CardIDChangelogService {
    static let shared = CardIDChangelogService()

    private let apiURL = "https://ygocdb-mirror.moecube.com/api/v0/idChangelog.jsonp"
    private let cacheTTL: TimeInterval = 12 * 60 * 60
    private let session: URLSession
    private let logger = Logger(subsystem: "com.ygocdb", category: "CardIDChangelogService")

    /// 缓存的 ID 映射（旧 ID -> 新 ID）
    private var cachedMappings: [Int: Int]?
    private var lastModified: String?
    private var etag: String?
    private var lastFetchDate: Date?

    private enum UpdateCheckResult {
        case updated
        case notUpdated
        case unknown
    }

    private init() {
        self.session = NetworkConfig.shared
    }

    /// 获取 ID 变更映射
    func fetchMappings(forceRefresh: Bool = false) async throws -> [Int: Int] {
        guard let url = URL(string: apiURL) else {
            throw CardIDChangelogError.invalidURL
        }

        if !forceRefresh, let cached = cachedMappings {
            let cacheAge = lastFetchDate.map { Date().timeIntervalSince($0) } ?? .infinity
            let isCacheFresh = cacheAge < cacheTTL
            do {
                let updateResult = try await checkForUpdates(url: url)
                switch updateResult {
                case .notUpdated:
                    logger.info("📦 ID 变更记录未更新，使用缓存 (\(cached.count) 条)")
                    return cached
                case .unknown:
                    if isCacheFresh {
                        logger.info("📦 无更新头但缓存仍在 TTL 内，使用缓存 (\(cached.count) 条)")
                        return cached
                    }
                    logger.info("⚠️ 无更新头且缓存超出 TTL，重新下载")
                case .updated:
                    logger.info("🔄 ID 变更记录有更新，重新下载")
                }
            } catch {
                if isCacheFresh {
                    logger.info("⚠️ HEAD 检查失败但缓存仍在 TTL 内，使用缓存 (\(cached.count) 条)")
                    return cached
                }
                logger.info("⚠️ HEAD 检查失败且缓存超出 TTL，重新下载")
            }
        }

        logger.info("📥 正在获取 ID 变更记录: \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logger.error("❌ ID 变更记录请求失败")
            throw CardIDChangelogError.requestFailed
        }

        if let newEtag = httpResponse.value(forHTTPHeaderField: "ETag") {
            etag = newEtag
            logger.info("📝 保存 ID 记录 ETag: \(newEtag)")
        }
        if let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
            lastModified = newLastModified
            logger.info("📝 保存 ID 记录 Last-Modified: \(newLastModified)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            logger.error("❌ ID 变更记录解析失败")
            throw CardIDChangelogError.decodingFailed
        }

        let mappings = try Self.parseMappings(from: text)
        cachedMappings = mappings
        lastFetchDate = Date()
        logger.info("✅ 获取到 \(mappings.count) 条 ID 变更记录")
        return mappings
    }

    /// 使用 HEAD 请求检查是否有更新
    private func checkForUpdates(url: URL) async throws -> UpdateCheckResult {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        logger.info("🔍 HEAD 检查 ID 记录更新: \(url.absoluteString)")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // HEAD 异常时返回未知
            return .unknown
        }

        if let newEtag = httpResponse.value(forHTTPHeaderField: "ETag"),
           let cachedEtag = etag {
            let hasUpdate = newEtag != cachedEtag
            logger.info("📊 ID 记录 ETag 比较: \(cachedEtag) vs \(newEtag) -> \(hasUpdate ? "有更新" : "无更新")")
            return hasUpdate ? .updated : .notUpdated
        }

        if let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified"),
           let cachedLastModified = lastModified {
            let hasUpdate = newLastModified != cachedLastModified
            logger.info("📊 ID 记录 Last-Modified 比较: \(cachedLastModified) vs \(newLastModified) -> \(hasUpdate ? "有更新" : "无更新")")
            return hasUpdate ? .updated : .notUpdated
        }

        logger.info("⚠️ 无法获取 ID 记录 ETag/Last-Modified")
        return .unknown
    }

    /// 获取缓存映射
    func getCachedMappings() -> [Int: Int] {
        cachedMappings ?? [:]
    }

    /// 清除缓存
    func clearCache() {
        cachedMappings = nil
        lastModified = nil
        etag = nil
        lastFetchDate = nil
        logger.info("🗑️ ID 变更记录缓存已清除")
    }

    static func parseMappings(from text: String) throws -> [Int: Int] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start < end {
            let json = Data(trimmed[start...end].utf8)
            let rawMappings = try JSONDecoder().decode([String: Int].self, from: json)
            var mappings: [Int: Int] = [:]
            mappings.reserveCapacity(rawMappings.count)

            for (oldIdText, newId) in rawMappings {
                guard let oldId = Int(oldIdText),
                      oldId > 0,
                      newId > 0,
                      oldId != newId else {
                    continue
                }
                mappings[oldId] = newId
            }

            return mappings
        }

        var mappings: [Int: Int] = [:]
        mappings.reserveCapacity(1024)

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2,
                  let oldId = Int(parts[0]),
                  let newId = Int(parts[1]),
                  oldId > 0,
                  newId > 0,
                  oldId != newId else {
                continue
            }

            mappings[oldId] = newId
        }

        return mappings
    }
}

enum CardIDChangelogError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .requestFailed:
            return "请求失败"
        case .decodingFailed:
            return "数据解析失败"
        }
    }
}
