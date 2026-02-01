//
//  SideboardStrategy.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/31.
//

import Foundation

enum SideboardPlayOrder: String, Codable, CaseIterable, Identifiable {
    case first = "先攻"
    case second = "后攻"

    var id: String { rawValue }
}

struct SideboardCardChange: Codable, Identifiable, Equatable {
    let cardId: Int
    var count: Int

    var id: Int { cardId }
}

struct SideboardSwapSet: Codable, Equatable {
    var swapOutMain: [SideboardCardChange]
    var swapInMain: [SideboardCardChange]
    var swapOutExtra: [SideboardCardChange]
    var swapInExtra: [SideboardCardChange]

    init(
        swapOutMain: [SideboardCardChange] = [],
        swapInMain: [SideboardCardChange] = [],
        swapOutExtra: [SideboardCardChange] = [],
        swapInExtra: [SideboardCardChange] = []
    ) {
        self.swapOutMain = swapOutMain
        self.swapInMain = swapInMain
        self.swapOutExtra = swapOutExtra
        self.swapInExtra = swapInExtra
    }
}

struct SideboardStrategy: Codable, Identifiable, Equatable {
    var id: UUID
    var vsDeckName: String
    var first: SideboardSwapSet
    var second: SideboardSwapSet

    init(
        id: UUID = UUID(),
        vsDeckName: String,
        first: SideboardSwapSet = SideboardSwapSet(),
        second: SideboardSwapSet = SideboardSwapSet()
    ) {
        self.id = id
        self.vsDeckName = vsDeckName
        self.first = first
        self.second = second
    }

    static func defaultStrategy() -> SideboardStrategy {
        SideboardStrategy(vsDeckName: "对战卡组")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case vsDeckName
        case first
        case second
        // 兼容旧字段
        case playOrder
        case swapOutMain
        case swapInMain
        case swapOutExtra
        case swapInExtra
        case swapOut
        case swapIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vsDeckName = try container.decode(String.self, forKey: .vsDeckName)
        if let first = try container.decodeIfPresent(SideboardSwapSet.self, forKey: .first),
           let second = try container.decodeIfPresent(SideboardSwapSet.self, forKey: .second) {
            self.first = first
            self.second = second
        } else {
            let order = try container.decodeIfPresent(SideboardPlayOrder.self, forKey: .playOrder) ?? .first
            let swapOutMain = try container.decodeIfPresent([SideboardCardChange].self, forKey: .swapOutMain)
                ?? container.decodeIfPresent([SideboardCardChange].self, forKey: .swapOut)
                ?? []
            let swapInMain = try container.decodeIfPresent([SideboardCardChange].self, forKey: .swapInMain)
                ?? container.decodeIfPresent([SideboardCardChange].self, forKey: .swapIn)
                ?? []
            let swapOutExtra = try container.decodeIfPresent([SideboardCardChange].self, forKey: .swapOutExtra) ?? []
            let swapInExtra = try container.decodeIfPresent([SideboardCardChange].self, forKey: .swapInExtra) ?? []
            let legacySet = SideboardSwapSet(
                swapOutMain: swapOutMain,
                swapInMain: swapInMain,
                swapOutExtra: swapOutExtra,
                swapInExtra: swapInExtra
            )
            if order == .first {
                self.first = legacySet
                self.second = SideboardSwapSet()
            } else {
                self.first = SideboardSwapSet()
                self.second = legacySet
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(vsDeckName, forKey: .vsDeckName)
        try container.encode(first, forKey: .first)
        try container.encode(second, forKey: .second)
    }
}
