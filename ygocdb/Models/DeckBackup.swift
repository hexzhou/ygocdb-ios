//
//  DeckBackup.swift
//  ygocdb
//
//  Created by hexzhou on 2026/02/01.
//

import Foundation

/// 卡组备份文件
struct DeckBackup: Codable {
    var version: Int
    var exportedAt: Date
    var decks: [Deck]

    init(version: Int = 1, exportedAt: Date = Date(), decks: [Deck]) {
        self.version = version
        self.exportedAt = exportedAt
        self.decks = decks
    }
}

enum DeckBackupImportMode {
    case merge
    case replace
}

struct DeckBackupImportSummary {
    let total: Int
    let added: Int
    let replaced: Int
}
