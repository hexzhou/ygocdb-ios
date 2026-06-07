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

    init(id: UUID, cardId: Int, deckType: DeckType) {
        self.id = id
        self.cardId = cardId
        self.deckType = deckType
    }

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

    /// 复制卡组
    func duplicated(name: String) -> Deck {
        var copy = Deck(name: name)
        copy.cards = cards.map { DeckCardItem(cardId: $0.cardId, deckType: $0.deckType) }
        copy.probabilityScenarios = probabilityScenarios.map { scenario in
            var duplicatedScenario = scenario
            duplicatedScenario.id = UUID()
            duplicatedScenario.groups = scenario.groups.map { group in
                var duplicatedGroup = group
                duplicatedGroup.id = UUID()
                return duplicatedGroup
            }
            return duplicatedScenario
        }
        copy.sideboardStrategies = sideboardStrategies.map { strategy in
            var duplicatedStrategy = strategy
            duplicatedStrategy.id = UUID()
            return duplicatedStrategy
        }
        copy.createdAt = Date()
        copy.updatedAt = copy.createdAt
        return copy
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
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return nil }

        if looksLikeYDK(trimmedCode) {
            return importFromYDK(trimmedCode, name: name) ?? importFromBase64Code(trimmedCode, name: name)
        }

        return importFromBase64Code(trimmedCode, name: name) ?? importFromYDK(trimmedCode, name: name)
    }

    /// 解析 YDK 格式（#main/#extra/!side）
    private static func importFromYDK(_ code: String, name: String) -> Deck? {
        var deck = Deck(name: name)

        let normalized = code.replacingOccurrences(of: "\r", with: "")
        let lines = normalized.components(separatedBy: .newlines)
        var currentType: DeckType = .main

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // 跳过空行和注释
            if trimmed.isEmpty || (trimmed.hasPrefix("#") && trimmed != "#main" && trimmed != "#extra") {
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

    /// 解析 Base64 格式
    /// 结构: [Int32 main+extra 数量][Int32 side 数量][main+extra 卡密...][side 卡密...]
    private static func importFromBase64Code(_ code: String, name: String) -> Deck? {
        let compactCode = code.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let data = Data(base64Encoded: compactCode), data.count >= 8 else {
            return nil
        }

        var offset = 0
        guard let mainAndExtraCount = readInt32LE(from: data, offset: &offset),
              let sideCount = readInt32LE(from: data, offset: &offset),
              mainAndExtraCount >= 0,
              sideCount >= 0 else {
            return nil
        }

        let expectedBytes = 8 + (mainAndExtraCount + sideCount) * 4
        guard expectedBytes == data.count else {
            return nil
        }

        var deck = Deck(name: name)

        for _ in 0..<mainAndExtraCount {
            guard let cardId = readInt32LE(from: data, offset: &offset) else { return nil }
            guard cardId > 100 else { continue }

            if isExtraDeckCard(cardId) {
                deck.addCard(cardId: cardId, to: .extra)
            } else {
                deck.addCard(cardId: cardId, to: .main)
            }
        }

        for _ in 0..<sideCount {
            guard let cardId = readInt32LE(from: data, offset: &offset) else { return nil }
            guard cardId > 100 else { continue }
            deck.addCard(cardId: cardId, to: .side)
        }

        return deck.isEmpty ? nil : deck
    }

    private static func looksLikeYDK(_ code: String) -> Bool {
        let normalized = code.replacingOccurrences(of: "\r", with: "")
        let lines = normalized.components(separatedBy: .newlines)
        var hasNumericLines = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line == "#main" || line == "#extra" || line == "!side" {
                return true
            }
            if line.hasPrefix("#") {
                continue
            }
            if Int(line) != nil {
                hasNumericLines = true
                continue
            }
            return false
        }

        return hasNumericLines
    }

    private static func readInt32LE(from data: Data, offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }

        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        offset += 4

        return Int(Int32(bitPattern: b0 | b1 | b2 | b3))
    }

    private static func isExtraDeckCard(_ cardId: Int) -> Bool {
        guard let card = CardRepository.shared.getCard(byId: cardId) else {
            return false
        }

        let cardType = card.cardType
        return cardType.contains(.fusion) ||
            cardType.contains(.synchro) ||
            cardType.contains(.xyz) ||
            cardType.contains(.link)
    }
}

/// 组卡器展示排序，尽量对齐 `ygopro2_unity2021` 的 `CardsManager.comparisonOfCard()`
enum DeckCardDisplaySorter {
    static func sortedItems(_ items: [DeckCardItem]) -> [DeckCardItem] {
        let metadataByCardId = metadataMap(for: items.map(\.cardId))
        return items.sorted { lhs, rhs in
            let comparison = compare(
                lhs.cardId,
                rhs.cardId,
                metadataByCardId: metadataByCardId
            )
            if comparison == 0 {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return comparison < 0
        }
    }

    static func sortCardGroups<T>(_ groups: [T], cardId: KeyPath<T, Int>) -> [T] {
        let metadataByCardId = metadataMap(for: groups.map { $0[keyPath: cardId] })
        return groups.sorted { lhs, rhs in
            compare(
                lhs[keyPath: cardId],
                rhs[keyPath: cardId],
                metadataByCardId: metadataByCardId
            ) < 0
        }
    }

    private static func metadataMap(for cardIds: [Int]) -> [Int: DeckCardDisplayMetadata] {
        Dictionary(uniqueKeysWithValues: Set(cardIds).map { cardId in
            (cardId, metadata(for: cardId))
        })
    }

    private static func metadata(for cardId: Int) -> DeckCardDisplayMetadata {
        guard let card = CardRepository.shared.getCard(byId: cardId),
              let data = card.data else {
            return .missing(cardId: cardId)
        }

        let type = data.type ?? 0
        return DeckCardDisplayMetadata(
            hasReferenceData: true,
            baseType: type & 0x7,
            subType: type >> 3,
            level: data.level ?? Int.min,
            attack: data.atk ?? Int.min,
            attribute: data.attribute ?? Int.max,
            race: data.race ?? Int.max,
            cardId: cardId
        )
    }

    private static func compare(
        _ lhsCardId: Int,
        _ rhsCardId: Int,
        metadataByCardId: [Int: DeckCardDisplayMetadata]
    ) -> Int {
        let lhs = metadataByCardId[lhsCardId] ?? .missing(cardId: lhsCardId)
        let rhs = metadataByCardId[rhsCardId] ?? .missing(cardId: rhsCardId)

        if lhs.hasReferenceData != rhs.hasReferenceData {
            return lhs.hasReferenceData ? -1 : 1
        }

        if lhs.baseType != rhs.baseType {
            return lhs.baseType < rhs.baseType ? -1 : 1
        }
        if lhs.subType != rhs.subType {
            return lhs.subType < rhs.subType ? -1 : 1
        }
        if lhs.level != rhs.level {
            return lhs.level > rhs.level ? -1 : 1
        }
        if lhs.attack != rhs.attack {
            return lhs.attack > rhs.attack ? -1 : 1
        }
        if lhs.attribute != rhs.attribute {
            return lhs.attribute < rhs.attribute ? -1 : 1
        }
        if lhs.race != rhs.race {
            return lhs.race < rhs.race ? -1 : 1
        }

        // `ygopro2` 这里还会比较 `Category`，但当前数据源没有该字段，直接回退到卡片 ID。
        if lhs.cardId != rhs.cardId {
            return lhs.cardId < rhs.cardId ? -1 : 1
        }

        return 0
    }
}

private struct DeckCardDisplayMetadata {
    let hasReferenceData: Bool
    let baseType: Int
    let subType: Int
    let level: Int
    let attack: Int
    let attribute: Int
    let race: Int
    let cardId: Int

    static func missing(cardId: Int) -> DeckCardDisplayMetadata {
        DeckCardDisplayMetadata(
            hasReferenceData: false,
            baseType: Int.max,
            subType: Int.max,
            level: Int.min,
            attack: Int.min,
            attribute: Int.max,
            race: Int.max,
            cardId: cardId
        )
    }
}
