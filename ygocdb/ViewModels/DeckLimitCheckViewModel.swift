//
//  DeckLimitCheckViewModel.swift
//  ygocdb
//

import Foundation
import Combine

@MainActor
final class DeckLimitCheckViewModel: ObservableObject {
    @Published private(set) var response: LimitListResponse? {
        didSet { evaluationCache = nil }
    }
    @Published var selectedEnvironment: LimitEnvironment = .ocg {
        didSet { evaluationCache = nil }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private struct EvaluationCacheKey: Equatable {
        let deckID: UUID
        let deckUpdatedAt: Date
        let environment: String
    }

    private var evaluationCache: (key: EvaluationCacheKey, values: [DeckLimitEvaluation])?

    init(response: LimitListResponse? = nil) {
        self.response = response
    }

    func currentEvaluation(for deck: Deck) -> DeckLimitEvaluation? {
        guard let response else { return nil }
        let currentDate = response.list(for: selectedEnvironment).date
        return evaluations(for: deck).first { $0.date == currentDate }
    }

    func evaluations(for deck: Deck) -> [DeckLimitEvaluation] {
        guard let response else { return [] }
        let key = EvaluationCacheKey(
            deckID: deck.id,
            deckUpdatedAt: deck.updatedAt,
            environment: selectedEnvironment.rawValue
        )
        if evaluationCache?.key == key {
            return evaluationCache?.values ?? []
        }

        let values = DeckLimitChecker.evaluate(
            deck: deck,
            against: response.datedLists(for: selectedEnvironment),
            referencesByCardID: references(for: deck)
        )
        evaluationCache = (key, values)
        return values
    }

    func load(forceRefresh: Bool = false) async {
        if response != nil, !forceRefresh { return }

        errorMessage = nil
        if !forceRefresh, let cached = await LimitListService.shared.cachedLimitLists() {
            response = cached
        }
        isLoading = forceRefresh || response == nil

        do {
            response = try await LimitListService.shared.fetchLimitLists(forceRefresh: forceRefresh)
        } catch {
            if error.isTaskCancellation || Task.isCancelled {
                isLoading = false
                return
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    private func references(for deck: Deck) -> [Int: DeckLimitCardReference] {
        Dictionary(uniqueKeysWithValues: Set(deck.cards.map(\.cardId)).compactMap { cardID in
            guard let card = CardRepository.shared.getCard(byId: cardID) else { return nil }
            return (
                cardID,
                DeckLimitCardReference(
                    cardID: cardID,
                    cid: card.cid,
                    name: AppSettings.shared.getDisplayName(for: card)
                )
            )
        })
    }
}
