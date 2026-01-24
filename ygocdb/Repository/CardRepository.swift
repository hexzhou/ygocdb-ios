//
//  CardRepository.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import Combine

/// 搜索索引结构，用于缓存预计算的小写字符串
private struct CardSearchIndex {
    let cardId: Int
    let cnName: String?
    let scName: String?
    let mdName: String?
    let nwbbsN: String?
    let cnocgN: String?
    let jpName: String?
    let jpRuby: String?
    let enName: String?
    let descDisplay: String
    let idString: String

    init(from card: Card) {
        self.cardId = card.id
        self.cnName = card.cnName?.lowercased()
        self.scName = card.scName?.lowercased()
        self.mdName = card.mdName?.lowercased()
        self.nwbbsN = card.nwbbsN?.lowercased()
        self.cnocgN = card.cnocgN?.lowercased()
        self.jpName = card.jpName?.lowercased()
        self.jpRuby = card.jpRuby?.lowercased()
        self.enName = card.enName?.lowercased()
        self.descDisplay = card.descDisplay.lowercased()
        self.idString = String(card.id)
    }

    func matches(_ lowercasedQuery: String) -> Bool {
        // 搜索所有语言的卡名
        if let cnName = cnName, cnName.contains(lowercasedQuery) { return true }
        if let scName = scName, scName.contains(lowercasedQuery) { return true }
        if let mdName = mdName, mdName.contains(lowercasedQuery) { return true }
        if let nwbbsN = nwbbsN, nwbbsN.contains(lowercasedQuery) { return true }
        if let cnocgN = cnocgN, cnocgN.contains(lowercasedQuery) { return true }
        if let jpName = jpName, jpName.contains(lowercasedQuery) { return true }
        if let jpRuby = jpRuby, jpRuby.contains(lowercasedQuery) { return true }
        if let enName = enName, enName.contains(lowercasedQuery) { return true }

        // 搜索效果文本
        if descDisplay.contains(lowercasedQuery) { return true }

        // 搜索卡片密码
        if idString == lowercasedQuery { return true }

        return false
    }
}

/// 卡片数据仓库，负责本地存储和检索
@MainActor
class CardRepository: ObservableObject {
    static let shared = CardRepository()

    @Published private(set) var cards: [Card] = []
    @Published private(set) var isLoaded: Bool = false

    private let fileManager = FileManager.default
    private let cardsFileName = "cards.json"
    private let md5FileName = "cards_md5.txt"

    /// 搜索索引缓存（预计算的小写字符串）
    private var searchIndexes: [CardSearchIndex] = []

    private init() {}
    
    /// 获取文档目录中的文件 URL
    private func fileURL(for fileName: String) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    /// 检查本地是否有缓存的卡片数据
    var hasLocalData: Bool {
        fileManager.fileExists(atPath: fileURL(for: cardsFileName).path)
    }
    
    /// 从本地加载卡片数据
    func loadCards() async throws {
        let url = fileURL(for: cardsFileName)

        guard fileManager.fileExists(atPath: url.path) else {
            cards = []
            searchIndexes = []
            isLoaded = false
            return
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let cardDatabase = try decoder.decode(CardDatabase.self, from: data)

        cards = Array(cardDatabase.values).sorted { $0.cid < $1.cid }

        // 构建搜索索引（预计算小写字符串）
        searchIndexes = cards.map { CardSearchIndex(from: $0) }

        isLoaded = true
    }
    
    /// 保存卡片数据到本地
    func saveCards(_ cardDatabase: CardDatabase, md5: String) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(cardDatabase)

        let cardsURL = fileURL(for: cardsFileName)
        try data.write(to: cardsURL)

        let md5URL = fileURL(for: md5FileName)
        try md5.write(to: md5URL, atomically: true, encoding: .utf8)

        cards = Array(cardDatabase.values).sorted { $0.cid < $1.cid }

        // 构建搜索索引（预计算小写字符串）
        searchIndexes = cards.map { CardSearchIndex(from: $0) }

        isLoaded = true
    }
    
    /// 获取本地保存的 MD5 值
    func getLocalMD5() -> String? {
        let url = fileURL(for: md5FileName)
        return try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 检查是否需要更新
    func checkForUpdates() async throws -> Bool {
        guard let localMD5 = getLocalMD5() else {
            return true // 没有本地数据，需要下载
        }
        
        let remoteMD5 = try await YGODBService.shared.fetchMD5()
        return localMD5 != remoteMD5
    }
    
    /// 清除所有卡片数据
    func clearCardData() {
        let cardsURL = fileURL(for: cardsFileName)
        let md5URL = fileURL(for: md5FileName)

        try? fileManager.removeItem(at: cardsURL)
        try? fileManager.removeItem(at: md5URL)

        cards = []
        searchIndexes = []
        isLoaded = false
    }
    
    /// 获取卡片数据大小（字节）
    func dataSize() -> Int64 {
        let cardsURL = fileURL(for: cardsFileName)
        guard let attributes = try? fileManager.attributesOfItem(atPath: cardsURL.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
    
    /// 格式化数据大小
    func formattedDataSize() -> String {
        let size = dataSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// 获取所有卡片
    func getAllCards() -> [Card] {
        return cards
    }
    
    /// 搜索卡片（优化版本：异步后台搜索，使用预计算的索引）
    func search(_ query: String) async -> [Card] {
        guard !query.isEmpty else {
            return []
        }

        // 捕获需要的数据到局部变量
        let cardsSnapshot = self.cards
        let indexesSnapshot = self.searchIndexes

        // 在后台线程执行搜索，避免阻塞主线程
        return await Task.detached {
            let lowercasedQuery = query.lowercased()
            var results: [Card] = []

            // 使用搜索索引进行快速匹配
            for (index, searchIndex) in indexesSnapshot.enumerated() {
                if searchIndex.matches(lowercasedQuery) {
                    results.append(cardsSnapshot[index])
                }
            }

            return results
        }.value
    }
}
