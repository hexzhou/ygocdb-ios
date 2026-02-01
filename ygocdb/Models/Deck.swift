//
//  Deck.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import Foundation

/// 卡组类型
enum DeckType: String, Codable {
    case main = "主卡组"
    case extra = "额外卡组"
    case side = "副卡组"
}

/// 卡组中的卡片项
struct DeckCardItem: Codable, Identifiable {
    let id: UUID
    let cardId: Int  // 卡片密码
    let deckType: DeckType

    init(cardId: Int, deckType: DeckType) {
        self.id = UUID()
        self.cardId = cardId
        self.deckType = deckType
    }
}

/// 卡组模型
struct Deck: Codable, Identifiable {
    let id: UUID
    var name: String
    var cards: [DeckCardItem]
    var probabilityScenarios: [ProbabilityScenario] = []
    var sideboardStrategies: [SideboardStrategy] = []
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.cards = []
        self.probabilityScenarios = []
        self.sideboardStrategies = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cards
        case probabilityScenarios
        case sideboardStrategies
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cards = try container.decode([DeckCardItem].self, forKey: .cards)
        probabilityScenarios = try container.decodeIfPresent([ProbabilityScenario].self, forKey: .probabilityScenarios) ?? []
        sideboardStrategies = try container.decodeIfPresent([SideboardStrategy].self, forKey: .sideboardStrategies) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    /// 获取主卡组卡片
    var mainDeckCards: [DeckCardItem] {
        cards.filter { $0.deckType == .main }
    }

    /// 获取额外卡组卡片
    var extraDeckCards: [DeckCardItem] {
        cards.filter { $0.deckType == .extra }
    }

    /// 获取副卡组卡片
    var sideDeckCards: [DeckCardItem] {
        cards.filter { $0.deckType == .side }
    }

    /// 主卡组数量
    var mainDeckCount: Int {
        mainDeckCards.count
    }

    /// 额外卡组数量
    var extraDeckCount: Int {
        extraDeckCards.count
    }

    /// 副卡组数量
    var sideDeckCount: Int {
        sideDeckCards.count
    }

    /// 总卡片数
    var totalCardCount: Int {
        cards.count
    }

    /// 是否为空卡组
    var isEmpty: Bool {
        cards.isEmpty
    }

    /// 添加卡片
    mutating func addCard(cardId: Int, to deckType: DeckType) {
        let item = DeckCardItem(cardId: cardId, deckType: deckType)
        cards.append(item)
        updatedAt = Date()
    }

    /// 移除卡片（按索引）
    mutating func removeCard(at index: Int, from deckType: DeckType) {
        let cardsInType = cards.enumerated().filter { $0.element.deckType == deckType }
        if index < cardsInType.count {
            let actualIndex = cardsInType[index].offset
            cards.remove(at: actualIndex)
            updatedAt = Date()
        }
    }

    /// 移除卡片（按ID）
    mutating func removeCard(id: UUID) {
        cards.removeAll { $0.id == id }
        updatedAt = Date()
    }

    /// 导出为卡组代码
    func exportToCode() -> String {
        var code = "#created by ygocdb\n"

        // 主卡组
        if !mainDeckCards.isEmpty {
            code += "#main\n"
            for card in mainDeckCards {
                code += String(format: "%08d\n", card.cardId)
            }
        }

        // 额外卡组
        if !extraDeckCards.isEmpty {
            code += "#extra\n"
            for card in extraDeckCards {
                code += String(format: "%08d\n", card.cardId)
            }
        }

        // 副卡组
        if !sideDeckCards.isEmpty {
            code += "!side\n"
            for card in sideDeckCards {
                code += String(format: "%08d\n", card.cardId)
            }
        }

        return code
    }

    /// 从卡组代码导入
    static func importFromCode(_ code: String, name: String) -> Deck? {
        var deck = Deck(name: name)

        let lines = code.components(separatedBy: .newlines)
        var currentType: DeckType = .main

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 跳过空行和注释
            if trimmed.isEmpty || trimmed.hasPrefix("#created") {
                continue
            }

            // 检查区域标记
            if trimmed == "#main" {
                currentType = .main
                continue
            } else if trimmed == "#extra" {
                currentType = .extra
                continue
            } else if trimmed == "!side" {
                currentType = .side
                continue
            }

            // 解析卡片密码（支持8位或更少）
            if let cardId = Int(trimmed), cardId > 0 {
                deck.addCard(cardId: cardId, to: currentType)
            }
        }

        return deck.isEmpty ? nil : deck
    }
}
