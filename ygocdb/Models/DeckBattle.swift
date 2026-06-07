//
//  DeckBattle.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/14.
//

import Foundation

/// 对战胜者
enum BattleWinner: String, Codable, CaseIterable, Identifiable {
    case deckAFirst = "A先攻胜"
    case deckASecond = "A后攻胜"
    case deckBFirst = "B先攻胜"
    case deckBSecond = "B后攻胜"

    var id: String { rawValue }

    /// 是否为A方获胜
    var isAWinner: Bool {
        self == .deckAFirst || self == .deckASecond
    }

    /// 是否为先攻获胜
    var isFirstPlayerWin: Bool {
        self == .deckAFirst || self == .deckBFirst
    }

    /// 获胜方标签
    var winnerLabel: String {
        switch self {
        case .deckAFirst: return "先攻胜"
        case .deckASecond: return "后攻胜"
        case .deckBFirst: return "先攻胜"
        case .deckBSecond: return "后攻胜"
        }
    }

    /// 简短标签（用于卡片上的小标记）
    var shortLabel: String {
        isAWinner ? "A胜" : "B胜"
    }
}

/// 单轮对决（一次洗牌抽卡）
struct BattleRound: Codable, Identifiable {
    let id: UUID
    let index: Int               // 第几轮（0-9）
    let deckAHand: [Int]         // A方抽到的卡片ID列表
    let deckBHand: [Int]         // B方抽到的卡片ID列表
    var winners: [BattleWinner]  // 胜者列表（支持多选）
    var note: String             // 单局备注

    init(
        id: UUID = UUID(),
        index: Int,
        deckAHand: [Int],
        deckBHand: [Int],
        winners: [BattleWinner] = [],
        note: String = ""
    ) {
        self.id = id
        self.index = index
        self.deckAHand = deckAHand
        self.deckBHand = deckBHand
        self.winners = winners
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        index = try container.decode(Int.self, forKey: .index)
        deckAHand = try container.decode([Int].self, forKey: .deckAHand)
        deckBHand = try container.decode([Int].self, forKey: .deckBHand)
        winners = try container.decode([BattleWinner].self, forKey: .winners)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

/// 对战记录（一次模拟 = 10轮对决）
struct BattleRecord: Codable, Identifiable {
    let id: UUID
    let deckAId: UUID
    let deckBId: UUID
    let deckAName: String
    let deckBName: String
    var rounds: [BattleRound]
    let isSided: Bool
    let sideChangesA: SideboardSwapSet?
    let sideChangesB: SideboardSwapSet?
    let note: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        deckAId: UUID,
        deckBId: UUID,
        deckAName: String,
        deckBName: String,
        rounds: [BattleRound] = [],
        isSided: Bool = false,
        sideChangesA: SideboardSwapSet? = nil,
        sideChangesB: SideboardSwapSet? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.deckAId = deckAId
        self.deckBId = deckBId
        self.deckAName = deckAName
        self.deckBName = deckBName
        self.rounds = rounds
        self.isSided = isSided
        self.sideChangesA = sideChangesA
        self.sideChangesB = sideChangesB
        self.note = note
        self.createdAt = createdAt
    }

    var markedCount: Int {
        rounds.filter { !$0.winners.isEmpty }.count
    }

    var aWinCount: Int {
        rounds.flatMap(\.winners).filter(\.isAWinner).count
    }

    var bWinCount: Int {
        rounds.flatMap(\.winners).filter { !$0.isAWinner }.count
    }

    var firstPlayerWinCount: Int {
        rounds.flatMap(\.winners).filter(\.isFirstPlayerWin).count
    }

    var secondPlayerWinCount: Int {
        rounds.flatMap(\.winners).filter { !$0.isFirstPlayerWin }.count
    }
}

/// 对战会话（一次对战模拟，包含多条记录）
struct BattleSession: Codable, Identifiable {
    let id: UUID
    let deckAId: UUID
    let deckBId: UUID
    let deckAName: String
    let deckBName: String
    var records: [BattleRecord]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        deckAId: UUID,
        deckBId: UUID,
        deckAName: String,
        deckBName: String,
        records: [BattleRecord] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.deckAId = deckAId
        self.deckBId = deckBId
        self.deckAName = deckAName
        self.deckBName = deckBName
        self.records = records
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 主卡组对局记录
    var mainRecords: [BattleRecord] {
        records.filter { !$0.isSided }
    }

    /// 换side对局记录
    var sidedRecords: [BattleRecord] {
        records.filter { $0.isSided }
    }

    var totalAWins: Int {
        records.flatMap(\.rounds).flatMap(\.winners).filter(\.isAWinner).count
    }

    var totalBWins: Int {
        records.flatMap(\.rounds).flatMap(\.winners).filter { !$0.isAWinner }.count
    }

    var totalFirstPlayerWins: Int {
        records.flatMap(\.rounds).flatMap(\.winners).filter(\.isFirstPlayerWin).count
    }

    var totalSecondPlayerWins: Int {
        records.flatMap(\.rounds).flatMap(\.winners).filter { !$0.isFirstPlayerWin }.count
    }

    var totalMarkedRounds: Int {
        records.flatMap(\.rounds).flatMap(\.winners).count
    }
}
