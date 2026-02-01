//
//  DeckService.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import Foundation

/// 卡组存储服务
class DeckService {
    static let shared = DeckService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// 卡组存储目录
    private var decksDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Decks", isDirectory: true)
    }

    private init() {
        createDecksDirectoryIfNeeded()
    }

    /// 创建卡组目录
    private func createDecksDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: decksDirectory.path) {
            try? fileManager.createDirectory(at: decksDirectory, withIntermediateDirectories: true)
        }
    }

    /// 获取所有卡组
    func loadAllDecks() -> [Deck] {
        guard let files = try? fileManager.contentsOfDirectory(at: decksDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        let decks = files.compactMap { url -> Deck? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let deck = try? decoder.decode(Deck.self, from: data) else {
                return nil
            }
            return deck
        }

        return decks.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 保存卡组
    func saveDeck(_ deck: Deck) throws {
        let fileURL = decksDirectory.appendingPathComponent("\(deck.id.uuidString).json")
        let data = try encoder.encode(deck)
        try data.write(to: fileURL)
    }

    /// 删除卡组
    func deleteDeck(_ deck: Deck) throws {
        let fileURL = decksDirectory.appendingPathComponent("\(deck.id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
    }

    /// 加载单个卡组
    func loadDeck(id: UUID) -> Deck? {
        let fileURL = decksDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL),
              let deck = try? decoder.decode(Deck.self, from: data) else {
            return nil
        }
        return deck
    }

    /// 删除所有卡组
    func deleteAllDecks() throws {
        guard let files = try? fileManager.contentsOfDirectory(at: decksDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in files where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }

    /// 导出卡组备份文件
    func exportBackup() throws -> URL {
        let decks = loadAllDecks()
        let backup = DeckBackup(decks: decks)
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "ygocdb-decks-backup-\(timestamp).json"

        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    /// 导入卡组备份
    func importBackup(from url: URL, mode: DeckBackupImportMode) throws -> DeckBackupImportSummary {
        let data = try Data(contentsOf: url)
        let backup: DeckBackup
        if let decoded = try? decoder.decode(DeckBackup.self, from: data) {
            backup = decoded
        } else {
            let decks = try decoder.decode([Deck].self, from: data)
            backup = DeckBackup(version: 0, decks: decks)
        }

        if mode == .replace {
            try deleteAllDecks()
        }

        let existingIds = Set(loadAllDecks().map { $0.id })
        var added = 0
        var replaced = 0

        for deck in backup.decks {
            if existingIds.contains(deck.id) {
                replaced += 1
            } else {
                added += 1
            }
            try saveDeck(deck)
        }

        return DeckBackupImportSummary(total: backup.decks.count, added: added, replaced: replaced)
    }
}
