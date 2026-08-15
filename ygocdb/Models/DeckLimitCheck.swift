//
//  DeckLimitCheck.swift
//  ygocdb
//

import Foundation

/// 卡组密码到官网 CID 的映射。相同卡片的不同密码会按 CID 合并计算。
struct DeckLimitCardReference: Equatable {
    let cardID: Int
    let cid: Int
    let name: String
}

struct DeckLimitViolation: Identifiable, Equatable {
    let cid: Int
    let representativeCardID: Int
    let name: String
    let status: CardLimitStatus?
    let actualCount: Int
    let allowedCount: Int
    let mainCount: Int
    let extraCount: Int
    let sideCount: Int

    var id: Int { cid }
}

struct UnresolvedDeckCard: Identifiable, Equatable {
    let cardID: Int
    let count: Int

    var id: Int { cardID }
}

enum DeckLimitEvaluationOutcome: Equatable {
    case empty
    case compliant
    case noncompliant
    case incomplete
}

struct DeckLimitEvaluation: Identifiable, Equatable {
    let date: String
    let totalCardCount: Int
    let checkedCardCount: Int
    let violations: [DeckLimitViolation]
    let unresolvedCards: [UnresolvedDeckCard]

    var id: String { date }

    var unresolvedCardCount: Int {
        unresolvedCards.reduce(0) { $0 + $1.count }
    }

    var outcome: DeckLimitEvaluationOutcome {
        if totalCardCount == 0 {
            return .empty
        }
        if !violations.isEmpty {
            return .noncompliant
        }
        if !unresolvedCards.isEmpty {
            return .incomplete
        }
        return .compliant
    }
}

enum DeckLimitChecker {
    static func evaluate(
        deck: Deck,
        against list: DatedLimitListSnapshot,
        referencesByCardID: [Int: DeckLimitCardReference]
    ) -> DeckLimitEvaluation {
        evaluate(
            deck: deck,
            against: [list],
            referencesByCardID: referencesByCardID
        )[0]
    }

    /// 一次统计卡组，再依次套用各期卡表，避免判断年代时重复遍历整副卡组。
    static func evaluate(
        deck: Deck,
        against lists: [DatedLimitListSnapshot],
        referencesByCardID: [Int: DeckLimitCardReference]
    ) -> [DeckLimitEvaluation] {
        var countsByCID: [Int: ResolvedCardCounts] = [:]
        var unresolvedCounts: [Int: Int] = [:]

        for item in deck.cards {
            guard let reference = referencesByCardID[item.cardId] else {
                unresolvedCounts[item.cardId, default: 0] += 1
                continue
            }

            var counts = countsByCID[reference.cid] ?? ResolvedCardCounts(reference: reference)
            counts.add(to: item.deckType)
            countsByCID[reference.cid] = counts
        }

        let unresolvedCards = unresolvedCounts.map { cardID, count in
            UnresolvedDeckCard(cardID: cardID, count: count)
        }
        .sorted { $0.cardID < $1.cardID }
        let checkedCardCount = deck.totalCardCount - unresolvedCards.reduce(0) { $0 + $1.count }

        return lists.map { list in
            evaluate(
                totalCardCount: deck.totalCardCount,
                checkedCardCount: checkedCardCount,
                countsByCID: countsByCID,
                unresolvedCards: unresolvedCards,
                against: list
            )
        }
    }

    private static func evaluate(
        totalCardCount: Int,
        checkedCardCount: Int,
        countsByCID: [Int: ResolvedCardCounts],
        unresolvedCards: [UnresolvedDeckCard],
        against list: DatedLimitListSnapshot
    ) -> DeckLimitEvaluation {
        let violations = countsByCID.values.compactMap { counts -> DeckLimitViolation? in
            let status = list.snapshot.status(for: counts.reference.cid)
            let allowedCount = status?.rawValue ?? 3
            guard counts.total > allowedCount else { return nil }

            return DeckLimitViolation(
                cid: counts.reference.cid,
                representativeCardID: counts.reference.cardID,
                name: counts.reference.name,
                status: status,
                actualCount: counts.total,
                allowedCount: allowedCount,
                mainCount: counts.main,
                extraCount: counts.extra,
                sideCount: counts.side
            )
        }
        .sorted { lhs, rhs in
            if lhs.allowedCount != rhs.allowedCount {
                return lhs.allowedCount < rhs.allowedCount
            }
            if lhs.actualCount != rhs.actualCount {
                return lhs.actualCount > rhs.actualCount
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return DeckLimitEvaluation(
            date: list.date,
            totalCardCount: totalCardCount,
            checkedCardCount: checkedCardCount,
            violations: violations,
            unresolvedCards: unresolvedCards
        )
    }
}

private struct ResolvedCardCounts {
    let reference: DeckLimitCardReference
    var main = 0
    var extra = 0
    var side = 0

    var total: Int {
        main + extra + side
    }

    mutating func add(to deckType: DeckType) {
        switch deckType {
        case .main:
            main += 1
        case .extra:
            extra += 1
        case .side:
            side += 1
        }
    }
}
