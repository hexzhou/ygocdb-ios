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
        var deck = Deck(name: name)
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
