//
//  DeckBuilderViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import Foundation
import Combine

enum AddCardResult {
    case success
    case limitReached
    case deckFull
    case failed
}

/// 卡组构建器视图模型
@MainActor
class DeckBuilderViewModel: ObservableObject {
    @Published var decks: [Deck] = []
    @Published var currentDeck: Deck?
    @Published var showError = false
    @Published var errorMessage: String?

    private let deckService = DeckService.shared

    init() {
        loadDecks()
    }

    /// 加载所有卡组
    func loadDecks() {
        decks = deckService.loadAllDecks()
    }

    /// 创建新卡组
    func createDeck(name: String) {
        let deck = Deck(name: name)
        do {
            try deckService.saveDeck(deck)
            loadDecks()
        } catch {
            errorMessage = "创建卡组失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 删除卡组
    func deleteDeck(_ deck: Deck) {
        do {
            try deckService.deleteDeck(deck)
            loadDecks()
        } catch {
            errorMessage = "删除卡组失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 重命名卡组
    func renameDeck(_ deck: Deck, newName: String) {
        guard var updatedDeck = decks.first(where: { $0.id == deck.id }) else { return }
        updatedDeck.name = newName
        updatedDeck.updatedAt = Date()

        do {
            try deckService.saveDeck(updatedDeck)
            loadDecks()
        } catch {
            errorMessage = "重命名失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 复制卡组
    func duplicateDeck(_ deck: Deck, newName: String) {
        let duplicatedDeck = deck.duplicated(name: newName)

        do {
            try deckService.saveDeck(duplicatedDeck)
            loadDecks()
        } catch {
            errorMessage = "复制卡组失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 添加卡片到卡组
    func addCard(cardId: Int, to deckType: DeckType, in deck: Deck) -> AddCardResult {
        guard var updatedDeck = decks.first(where: { $0.id == deck.id }) else { return .failed }

        // 检查数量限制
        let currentCount = updatedDeck.cards.filter { $0.cardId == cardId }.count
        if currentCount >= 3 {
            return .limitReached
        }

        // 检查卡组上限
        switch deckType {
        case .main:
            if updatedDeck.mainDeckCount >= 60 {
                errorMessage = "主卡组已达上限（60张）"
                showError = true
                return .deckFull
            }
        case .extra:
            if updatedDeck.extraDeckCount >= 15 {
                errorMessage = "额外卡组已达上限（15张）"
                showError = true
                return .deckFull
            }
        case .side:
            if updatedDeck.sideDeckCount >= 15 {
                errorMessage = "副卡组已达上限（15张）"
                showError = true
                return .deckFull
            }
        }

        updatedDeck.addCard(cardId: cardId, to: deckType)

        do {
            try deckService.saveDeck(updatedDeck)
            loadDecks()
            currentDeck = updatedDeck
        } catch {
            errorMessage = "添加卡片失败: \(error.localizedDescription)"
            showError = true
            return .failed
        }
        return .success
    }

    /// 从卡组移除卡片
    func removeCard(id: UUID, from deck: Deck) {
        guard var updatedDeck = decks.first(where: { $0.id == deck.id }) else { return }
        updatedDeck.removeCard(id: id)

        do {
            try deckService.saveDeck(updatedDeck)
            loadDecks()
            currentDeck = updatedDeck
        } catch {
            errorMessage = "移除卡片失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 移动卡片到指定卡组类型
    func moveCard(itemId: UUID, cardId: Int, to deckType: DeckType, in deck: Deck) -> AddCardResult {
        guard var updatedDeck = decks.first(where: { $0.id == deck.id }) else { return .failed }

        // 检查目标卡组上限
        switch deckType {
        case .main:
            if updatedDeck.mainDeckCount >= 60 {
                errorMessage = "主卡组已达上限（60张）"
                showError = true
                return .deckFull
            }
        case .extra:
            if updatedDeck.extraDeckCount >= 15 {
                errorMessage = "额外卡组已达上限（15张）"
                showError = true
                return .deckFull
            }
        case .side:
            if updatedDeck.sideDeckCount >= 15 {
                errorMessage = "副卡组已达上限（15张）"
                showError = true
                return .deckFull
            }
        }

        updatedDeck.removeCard(id: itemId)
        updatedDeck.addCard(cardId: cardId, to: deckType)

        do {
            try deckService.saveDeck(updatedDeck)
            loadDecks()
            currentDeck = updatedDeck
        } catch {
            errorMessage = "移动卡片失败: \(error.localizedDescription)"
            showError = true
            return .failed
        }

        return .success
    }

    /// 更新卡组
    func updateDeck(_ deck: Deck) {
        var updatedDeck = deck
        updatedDeck.updatedAt = Date()
        do {
            try deckService.saveDeck(updatedDeck)
            loadDecks()
            currentDeck = updatedDeck
        } catch {
            errorMessage = "更新卡组失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 一键将已存在正式卡版本的先行卡替换为正式卡 ID
    /// - Returns: 实际被替换的卡片数量
    @discardableResult
    func replacePreReleaseCardsWithOfficial(in deck: Deck, idMappings: [Int: Int]) -> Int {
        guard var updatedDeck = decks.first(where: { $0.id == deck.id }) else { return 0 }

        func mapCardIds(_ ids: [Int]) -> [Int] {
            ids.map { oldId in
                guard let newId = idMappings[oldId] else {
                    return oldId
                }
                return newId
            }
        }

        func mapChanges(_ changes: [SideboardCardChange]) -> [SideboardCardChange] {
            changes.map { change in
                guard let newId = idMappings[change.cardId] else {
                    return change
                }
                return SideboardCardChange(cardId: newId, count: change.count)
            }
        }

        var replacedCount = 0
        var newItems: [DeckCardItem] = []
        newItems.reserveCapacity(updatedDeck.cards.count)

        for item in updatedDeck.cards {
            guard let newId = idMappings[item.cardId] else {
                newItems.append(item)
                continue
            }

            newItems.append(DeckCardItem(id: item.id, cardId: newId, deckType: item.deckType))
            replacedCount += 1
        }

        guard replacedCount > 0 else { return 0 }

        updatedDeck.cards = newItems
        updatedDeck.probabilityScenarios = updatedDeck.probabilityScenarios.map { scenario in
            var mapped = scenario
            mapped.groups = mapped.groups.map { group in
                var mappedGroup = group
                mappedGroup.cardIds = mapCardIds(group.cardIds)
                return mappedGroup
            }
            return mapped
        }
        updatedDeck.sideboardStrategies = updatedDeck.sideboardStrategies.map { strategy in
            var mapped = strategy
            mapped.first.swapOutMain = mapChanges(mapped.first.swapOutMain)
            mapped.first.swapInMain = mapChanges(mapped.first.swapInMain)
            mapped.first.swapOutExtra = mapChanges(mapped.first.swapOutExtra)
            mapped.first.swapInExtra = mapChanges(mapped.first.swapInExtra)
            mapped.second.swapOutMain = mapChanges(mapped.second.swapOutMain)
            mapped.second.swapInMain = mapChanges(mapped.second.swapInMain)
            mapped.second.swapOutExtra = mapChanges(mapped.second.swapOutExtra)
            mapped.second.swapInExtra = mapChanges(mapped.second.swapInExtra)
            return mapped
        }
        updatedDeck.updatedAt = Date()

        do {
            try deckService.saveDeck(updatedDeck)
            loadDecks()
            currentDeck = updatedDeck
        } catch {
            errorMessage = "切换正式卡失败: \(error.localizedDescription)"
            showError = true
            return 0
        }

        return replacedCount
    }

    /// 更新概率场景
    func updateProbabilityScenarios(_ scenarios: [ProbabilityScenario], for deck: Deck) {
        var updatedDeck = deck
        updatedDeck.probabilityScenarios = scenarios
        updateDeck(updatedDeck)
    }

    /// 更新副卡组策略
    func updateSideboardStrategies(_ strategies: [SideboardStrategy], for deck: Deck) {
        var updatedDeck = deck
        updatedDeck.sideboardStrategies = strategies
        updateDeck(updatedDeck)
    }
}
