//
//  DeckBattleViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/14.
//

import Foundation
import SwiftUI
import Combine

/// 对战模拟 ViewModel
@MainActor
class DeckBattleViewModel: ObservableObject {
    // MARK: - 常量
    static let roundCount = 5

    // MARK: - 卡组数据
    let originalDeckA: Deck
    let originalDeckB: Deck

    /// 当前使用的卡组（可能经过side调整）
    @Published var currentDeckA: Deck
    @Published var currentDeckB: Deck

    /// side变更记录
    @Published var sideChangesA: SideboardSwapSet?
    @Published var sideChangesB: SideboardSwapSet?

    // MARK: - 10次对决状态
    @Published var rounds: [BattleRound] = []
    @Published var drawSessionId = UUID()

    // MARK: - 对战会话
    @Published var session: BattleSession
    @Published var isLoading = false

    /// 是否处于换side模式
    @Published var isSided = false

    private let battleService = BattleService.shared

    init(deckA: Deck, deckB: Deck, existingSession: BattleSession? = nil) {
        self.originalDeckA = deckA
        self.originalDeckB = deckB
        self.currentDeckA = deckA
        self.currentDeckB = deckB

        if let existing = existingSession {
            self.session = existing
        } else {
            self.session = BattleSession(
                deckAId: deckA.id,
                deckBId: deckB.id,
                deckAName: deckA.name,
                deckBName: deckB.name
            )
            try? battleService.saveSession(self.session)
        }
    }

    // MARK: - 抽卡逻辑

    /// 执行10次对决抽卡
    func drawTenRounds() async {
        let mainAIds = currentDeckA.mainDeckCards.map(\.cardId)
        let mainBIds = currentDeckB.mainDeckCards.map(\.cardId)
        drawSessionId = UUID()

        var newRounds: [BattleRound] = []

        for i in 0..<Self.roundCount {
            let shuffledA = mainAIds.shuffled()
            let shuffledB = mainBIds.shuffled()
            let handA = Array(shuffledA.prefix(5))
            let handB = Array(shuffledB.prefix(5))

            let round = BattleRound(
                index: i,
                deckAHand: handA,
                deckBHand: handB
            )
            newRounds.append(round)
        }

        withAnimation {
            rounds = newRounds
        }
    }

    /// 为指定轮次的指定方+1抽卡
    func drawOneMore(roundIndex: Int, for side: BattleSide) {
        guard roundIndex < rounds.count else { return }
        let mainIds: [Int]
        switch side {
        case .a:
            mainIds = currentDeckA.mainDeckCards.map(\.cardId).shuffled()
        case .b:
            mainIds = currentDeckB.mainDeckCards.map(\.cardId).shuffled()
        }

        // 找一张不在已抽手牌中的卡（简化：直接从洗牌后找第6张以后的）
        let currentHand = side == .a ? rounds[roundIndex].deckAHand : rounds[roundIndex].deckBHand
        if let newCard = mainIds.first(where: { cardId in
            // 尝试找一张还没在手牌中的（考虑重复卡）
            var remaining = mainIds
            for existingId in currentHand {
                if let idx = remaining.firstIndex(of: existingId) {
                    remaining.remove(at: idx)
                }
            }
            return remaining.contains(cardId)
        }) {
            var updatedRound = rounds[roundIndex]
            switch side {
            case .a:
                var newHand = updatedRound.deckAHand
                newHand.append(newCard)
                updatedRound = BattleRound(
                    id: updatedRound.id,
                    index: updatedRound.index,
                    deckAHand: newHand,
                    deckBHand: updatedRound.deckBHand,
                    winners: updatedRound.winners,
                    note: updatedRound.note
                )
            case .b:
                var newHand = updatedRound.deckBHand
                newHand.append(newCard)
                updatedRound = BattleRound(
                    id: updatedRound.id,
                    index: updatedRound.index,
                    deckAHand: updatedRound.deckAHand,
                    deckBHand: newHand,
                    winners: updatedRound.winners,
                    note: updatedRound.note
                )
            }
            withAnimation {
                rounds[roundIndex] = updatedRound
            }
        }
    }

    enum BattleSide: String, Identifiable {
        case a, b
        var id: String { rawValue }
    }

    /// 解析卡片ID为 DrawnCard
    func resolveCard(cardId: Int) async -> DrawnCard? {
        if let card = CardRepository.shared.getCard(byId: cardId) {
            return .normal(card)
        } else if let preRelease = await PreReleaseCardService.shared.getCard(byId: cardId) {
            return .preRelease(preRelease)
        }
        return nil
    }

    // MARK: - 结果记录

    /// 标记/取消标记某轮的胜者（多选）
    func toggleRoundWinner(roundIndex: Int, winner: BattleWinner) {
        guard roundIndex < rounds.count else { return }
        if let idx = rounds[roundIndex].winners.firstIndex(of: winner) {
            rounds[roundIndex].winners.remove(at: idx)  // 取消
        } else {
            rounds[roundIndex].winners.append(winner)    // 添加
        }
    }

    /// 更新某轮的备注
    func updateRoundNote(roundIndex: Int, note: String) {
        guard roundIndex < rounds.count else { return }
        rounds[roundIndex].note = note
    }

    /// 保存当前10轮为一条记录
    func saveRecord(note: String = "") {
        let record = BattleRecord(
            deckAId: session.deckAId,
            deckBId: session.deckBId,
            deckAName: session.deckAName,
            deckBName: session.deckBName,
            rounds: rounds,
            isSided: isSided,
            sideChangesA: sideChangesA,
            sideChangesB: sideChangesB,
            note: note
        )

        session.records.append(record)
        session.updatedAt = Date()
        try? battleService.saveSession(session)
    }

    /// 删除一条记录
    func deleteRecord(_ record: BattleRecord) {
        session.records.removeAll { $0.id == record.id }
        session.updatedAt = Date()
        try? battleService.saveSession(session)
    }

    // MARK: - 换side

    /// 应用副卡组策略到指定卡组
    func applySideboardStrategy(_ strategy: SideboardSwapSet, for side: BattleSide) {
        switch side {
        case .a:
            currentDeckA = applySide(to: originalDeckA, swapSet: strategy)
            sideChangesA = strategy
        case .b:
            currentDeckB = applySide(to: originalDeckB, swapSet: strategy)
            sideChangesB = strategy
        }
        isSided = true
    }

    /// 直接设置换side后的卡组
    func setSidedDeck(_ deck: Deck, swapSet: SideboardSwapSet, for side: BattleSide) {
        switch side {
        case .a:
            currentDeckA = deck
            sideChangesA = swapSet
        case .b:
            currentDeckB = deck
            sideChangesB = swapSet
        }
        isSided = true
    }

    /// 重置为主卡组模式
    func resetToMainDeck() {
        currentDeckA = originalDeckA
        currentDeckB = originalDeckB
        sideChangesA = nil
        sideChangesB = nil
        isSided = false
    }

    /// 应用side更换到卡组（构建临时卡组）
    private func applySide(to deck: Deck, swapSet: SideboardSwapSet) -> Deck {
        var newDeck = deck

        for change in swapSet.swapOutMain {
            for _ in 0..<change.count {
                if let index = newDeck.cards.firstIndex(where: { $0.cardId == change.cardId && $0.deckType == .main }) {
                    newDeck.cards.remove(at: index)
                }
            }
        }

        for change in swapSet.swapInMain {
            for _ in 0..<change.count {
                if let index = newDeck.cards.firstIndex(where: { $0.cardId == change.cardId && $0.deckType == .side }) {
                    newDeck.cards.remove(at: index)
                }
                newDeck.cards.append(DeckCardItem(cardId: change.cardId, deckType: .main))
            }
        }

        for change in swapSet.swapOutExtra {
            for _ in 0..<change.count {
                if let index = newDeck.cards.firstIndex(where: { $0.cardId == change.cardId && $0.deckType == .extra }) {
                    newDeck.cards.remove(at: index)
                }
            }
        }

        for change in swapSet.swapInExtra {
            for _ in 0..<change.count {
                if let index = newDeck.cards.firstIndex(where: { $0.cardId == change.cardId && $0.deckType == .side }) {
                    newDeck.cards.remove(at: index)
                }
                newDeck.cards.append(DeckCardItem(cardId: change.cardId, deckType: .extra))
            }
        }

        return newDeck
    }

    /// 历史记录 - 主卡组对局
    var mainRecords: [BattleRecord] {
        session.records.filter { !$0.isSided }.reversed()
    }

    /// 历史记录 - 换side对局
    var sidedRecords: [BattleRecord] {
        session.records.filter { $0.isSided }.reversed()
    }

    /// 当前10轮的统计
    var currentAWins: Int {
        rounds.flatMap(\.winners).filter(\.isAWinner).count
    }

    var currentBWins: Int {
        rounds.flatMap(\.winners).filter { !$0.isAWinner }.count
    }

    var currentMarkedCount: Int {
        rounds.filter { !$0.winners.isEmpty }.count
    }
}
