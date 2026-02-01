//
//  ProbabilityCalcViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/30.
//

import Foundation
import Combine

struct ProbabilityDisplayResult {
    var base: ProbabilityCalculationOutput?
    var errorMessage: String?
}

@MainActor
class ProbabilityCalcViewModel: ObservableObject {
    @Published var results: [UUID: ProbabilityDisplayResult] = [:]
    @Published var calculating: Set<UUID> = []

    private var tasks: [UUID: Task<Void, Never>] = [:]

    func recalculateAll(scenarios: [ProbabilityScenario], deck: Deck) {
        for scenario in scenarios {
            recalculate(scenario: scenario, deck: deck)
        }
    }

    func recalculate(scenario: ProbabilityScenario, deck: Deck) {
        tasks[scenario.id]?.cancel()
        calculating.insert(scenario.id)

        let task = Task(priority: .userInitiated) { [scenario, deck] in
            let result = Self.computeResult(scenario: scenario, deck: deck)
            await MainActor.run {
                self.results[scenario.id] = result
                self.calculating.remove(scenario.id)
            }
        }
        tasks[scenario.id] = task
    }

    func calculatePreview(scenario: ProbabilityScenario, deck: Deck, completion: @escaping (ProbabilityDisplayResult) -> Void) {
        Task(priority: .userInitiated) { [scenario, deck] in
            let result = Self.computeResult(scenario: scenario, deck: deck)
            await MainActor.run {
                completion(result)
            }
        }
    }

    private static func computeResult(scenario: ProbabilityScenario, deck: Deck) -> ProbabilityDisplayResult {
        let mainCounts = deck.mainDeckCards.reduce(into: [Int: Int]()) { dict, item in
            dict[item.cardId, default: 0] += 1
        }
        do {
            let base = try ProbabilityCalculator.calculateBase(
                deckCounts: mainCounts,
                deckSize: deck.mainDeckCount,
                groups: scenario.groups,
                scenario: scenario
            )
            return ProbabilityDisplayResult(base: base, errorMessage: nil)
        } catch {
            return ProbabilityDisplayResult(base: nil, errorMessage: error.localizedDescription)
        }
    }
}
