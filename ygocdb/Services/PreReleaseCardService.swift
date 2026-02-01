//
//  PreReleaseCardService.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/13.
//

import Foundation
import os.log

/// 先行卡服务
actor PreReleaseCardService {
    static let shared = PreReleaseCardService()
    
    private let apiURL = "https://cdntx.moecube.com/ygopro-super-pre/data/test-release-v2.json"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.ygocdb", category: "PreReleaseCardService")
    
    /// 缓存的先行卡数据
    private var cachedCards: [PreReleaseCard]?
    private var lastModified: String?
    private var etag: String?
    
    private init() {
        self.session = NetworkConfig.shared
    }
    
    /// 获取先行卡列表
    func fetchCards(forceRefresh: Bool = false) async throws -> [PreReleaseCard] {
        guard let url = URL(string: apiURL) else {
            throw PreReleaseCardError.invalidURL
        }
        
        // 如果有缓存且不是强制刷新，先用 HEAD 检查是否有更新
        if !forceRefresh, let cached = cachedCards {
            let hasUpdate = try await checkForUpdates(url: url)
            if !hasUpdate {
                logger.info("📦 数据未更新，使用缓存 (\(cached.count) 张)")
                return cached
            }
            logger.info("🔄 检测到更新，重新下载数据")
        }
        
        // 从网络获取完整数据
        logger.info("📥 正在获取先行卡列表: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logger.error("❌ 先行卡 API 请求失败")
            throw PreReleaseCardError.requestFailed
        }
        
        // 保存 ETag 和 Last-Modified
        if let newEtag = httpResponse.value(forHTTPHeaderField: "ETag") {
            etag = newEtag
            logger.info("📝 保存 ETag: \(newEtag)")
        }
        if let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
            lastModified = newLastModified
            logger.info("📝 保存 Last-Modified: \(newLastModified)")
        }
        
        let decoder = JSONDecoder()
        let cards = try decoder.decode([PreReleaseCard].self, from: data)
        
        // 更新缓存
        cachedCards = cards
        
        logger.info("✅ 获取到 \(cards.count) 张先行卡")
        return cards
    }
    
    /// 使用 HEAD 请求检查是否有更新
    private func checkForUpdates(url: URL) async throws -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        logger.info("🔍 HEAD 检查更新: \(url.absoluteString)")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // 如果 HEAD 请求失败，保守起见认为有更新
            return true
        }
        
        // 检查 ETag
        if let newEtag = httpResponse.value(forHTTPHeaderField: "ETag"),
           let cachedEtag = etag {
            let hasUpdate = newEtag != cachedEtag
            logger.info("📊 ETag 比较: \(cachedEtag) vs \(newEtag) -> \(hasUpdate ? "有更新" : "无更新")")
            return hasUpdate
        }
        
        // 检查 Last-Modified
        if let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified"),
           let cachedLastModified = lastModified {
            let hasUpdate = newLastModified != cachedLastModified
            logger.info("📊 Last-Modified 比较: \(cachedLastModified) vs \(newLastModified) -> \(hasUpdate ? "有更新" : "无更新")")
            return hasUpdate
        }
        
        // 如果没有这些头信息，保守起见认为有更新
        logger.info("⚠️ 无法获取 ETag/Last-Modified，假设有更新")
        return true
    }
    
    /// 搜索先行卡
    func searchCards(query: String) async throws -> [PreReleaseCard] {
        let allCards = try await fetchCards()
        
        if query.isEmpty {
            return allCards
        }
        
        let lowercasedQuery = query.lowercased()
        
        return allCards.filter { card in
            card.name.lowercased().contains(lowercasedQuery) ||
            card.desc.lowercased().contains(lowercasedQuery) ||
            String(card.id).contains(query)
        }
    }
    
    /// 清除缓存
    func clearCache() {
        cachedCards = nil
        lastModified = nil
        etag = nil
        logger.info("🗑️ 先行卡缓存已清除")
    }

    /// 根据 ID 获取先行卡（从缓存中查找）
    func getCard(byId cardId: Int) -> PreReleaseCard? {
        cachedCards?.first(where: { $0.id == cardId })
    }

    /// 获取缓存的先行卡列表
    func getCachedCards() -> [PreReleaseCard] {
        cachedCards ?? []
    }
}

/// 先行卡服务错误
enum PreReleaseCardError: Error, LocalizedError {
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
