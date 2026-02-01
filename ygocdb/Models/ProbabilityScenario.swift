//
//  ProbabilityScenario.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/30.
//

import Foundation

/// 概率计算方法
enum ProbabilityCalculationMethod: String, Codable, CaseIterable, Identifiable {
    case auto = "自动"
    case exact = "精确"
    case monteCarlo = "模拟"

    var id: String { rawValue }
}

/// 概率计算场景
struct ProbabilityScenario: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var startingHand: Int
    var extraDraws: Int
    var method: ProbabilityCalculationMethod
    var simulations: Int
    var condition: String
    var groups: [ProbabilityGroup]

    init(
        id: UUID = UUID(),
        name: String,
        startingHand: Int = 5,
        extraDraws: Int = 0,
        method: ProbabilityCalculationMethod = .auto,
        simulations: Int = 100000,
        condition: String,
        groups: [ProbabilityGroup]
    ) {
        self.id = id
        self.name = name
        self.startingHand = startingHand
        self.extraDraws = extraDraws
        self.method = method
        self.simulations = simulations
        self.condition = condition
        self.groups = groups
    }

    /// 实际抽卡数
    var draws: Int {
        max(0, startingHand + extraDraws)
    }

    static func defaultScenario() -> ProbabilityScenario {
        ProbabilityScenario(
            name: "起手关键卡",
            startingHand: 5,
            extraDraws: 0,
            method: .auto,
            simulations: 100000,
            condition: "a > 0",
            groups: [
                ProbabilityGroup(label: "A", name: "关键卡")
            ]
        )
    }
}

/// 关键卡分组
struct ProbabilityGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var label: String
    var name: String
    var cardIds: [Int]

    init(id: UUID = UUID(), label: String, name: String, cardIds: [Int] = []) {
        self.id = id
        self.label = label
        self.name = name
        self.cardIds = cardIds
    }
}
