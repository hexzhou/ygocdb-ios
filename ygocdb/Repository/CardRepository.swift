//
//  CardRepository.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import Combine

/// 卡片数据仓库，负责本地存储和检索
@MainActor
class CardRepository: ObservableObject {
    static let shared = CardRepository()
    
    @Published private(set) var cards: [Card] = []
    @Published private(set) var isLoaded: Bool = false
    
    private let fileManager = FileManager.default
    private let cardsFileName = "cards.json"
    private let md5FileName = "cards_md5.txt"
    
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
            isLoaded = false
            return
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let cardDatabase = try decoder.decode(CardDatabase.self, from: data)
        
        cards = Array(cardDatabase.values).sorted { $0.cid < $1.cid }
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
    
    /// 搜索卡片
    func search(_ query: String) -> [Card] {
        guard !query.isEmpty else {
            return []
        }
        
        let lowercasedQuery = query.lowercased()
        
        return cards.filter { card in
            // 搜索所有语言的卡名
            if let cnName = card.cnName?.lowercased(), cnName.contains(lowercasedQuery) {
                return true
            }
            if let scName = card.scName?.lowercased(), scName.contains(lowercasedQuery) {
                return true
            }
            if let mdName = card.mdName?.lowercased(), mdName.contains(lowercasedQuery) {
                return true
            }
            if let nwbbsN = card.nwbbsN?.lowercased(), nwbbsN.contains(lowercasedQuery) {
                return true
            }
            if let cnocgN = card.cnocgN?.lowercased(), cnocgN.contains(lowercasedQuery) {
                return true
            }
            if let jpName = card.jpName?.lowercased(), jpName.contains(lowercasedQuery) {
                return true
            }
            if let jpRuby = card.jpRuby?.lowercased(), jpRuby.contains(lowercasedQuery) {
                return true
            }
            if let enName = card.enName?.lowercased(), enName.contains(lowercasedQuery) {
                return true
            }
            
            // 搜索效果文本
            if card.descDisplay.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // 搜索卡片密码
            if String(card.id) == query {
                return true
            }
            
            return false
        }
    }
}
