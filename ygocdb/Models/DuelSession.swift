//
//  DuelSession.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/22.
//

import Foundation

/// 初始 LP
let kInitialLP = 8000

/// LP 变化类型
enum LPChangeType: String, CaseIterable, Identifiable {
    case damage = "伤害"
    case recover = "恢复"
    case pay = "支付"
    case set = "设为"

    var id: String { rawValue }
}

/// LP 变化记录
struct LPChange: Identifiable {
    let id = UUID()
    let type: LPChangeType
    let value: Int
    let resultLP: Int
    let timestamp: Date

    init(type: LPChangeType, value: Int, resultLP: Int, timestamp: Date = Date()) {
        self.type = type
        self.value = value
        self.resultLP = resultLP
        self.timestamp = timestamp
    }
}

/// 玩家方
enum PlayerSide: String, CaseIterable, Identifiable {
    case playerA = "Player A"
    case playerB = "Player B"

    var id: String { rawValue }
}

/// 硬币结果
enum CoinResult: String {
    case heads = "正面"
    case tails = "反面"
}
