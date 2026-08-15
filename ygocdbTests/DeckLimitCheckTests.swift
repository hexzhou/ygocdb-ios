import Testing
@testable import ygocdb

struct DeckLimitCheckTests {
    @Test func checkerCombinesMainExtraAndSideCopiesByCID() {
        var deck = Deck(name: "限制测试")
        deck.addCard(cardId: 11111111, to: .main)
        deck.addCard(cardId: 11111111, to: .extra)
        deck.addCard(cardId: 22222222, to: .side)

        let references = [
            11111111: DeckLimitCardReference(cardID: 11111111, cid: 7000, name: "测试卡"),
            22222222: DeckLimitCardReference(cardID: 22222222, cid: 7000, name: "测试卡异画")
        ]
        let list = DatedLimitListSnapshot(
            date: "2026-07-01",
            snapshot: LimitListSnapshot(
                forbidden: [:],
                limited: ["7000": "测试卡"],
                semiLimited: [:]
            )
        )

        let evaluation = DeckLimitChecker.evaluate(
            deck: deck,
            against: list,
            referencesByCardID: references
        )

        #expect(evaluation.outcome == .noncompliant)
        #expect(evaluation.violations.count == 1)
        #expect(evaluation.violations.first?.actualCount == 3)
        #expect(evaluation.violations.first?.allowedCount == 1)
        #expect(evaluation.violations.first?.mainCount == 1)
        #expect(evaluation.violations.first?.extraCount == 1)
        #expect(evaluation.violations.first?.sideCount == 1)
    }

    @Test func unresolvedCardMakesOtherwiseValidResultIncomplete() {
        var deck = Deck(name: "未收录测试")
        deck.addCard(cardId: 11111111, to: .main)
        deck.addCard(cardId: 99999999, to: .main)

        let list = DatedLimitListSnapshot(
            date: "2026-07-01",
            snapshot: LimitListSnapshot(forbidden: [:], limited: [:], semiLimited: [:])
        )
        let evaluation = DeckLimitChecker.evaluate(
            deck: deck,
            against: list,
            referencesByCardID: [
                11111111: DeckLimitCardReference(cardID: 11111111, cid: 7000, name: "测试卡")
            ]
        )

        #expect(evaluation.outcome == .incomplete)
        #expect(evaluation.checkedCardCount == 1)
        #expect(evaluation.unresolvedCardCount == 1)
        #expect(evaluation.unresolvedCards.first?.cardID == 99999999)
    }

    @Test func checkerEvaluatesMultiplePeriodsFromOnePreparedDeck() {
        var deck = Deck(name: "年代测试")
        deck.addCard(cardId: 11111111, to: .main)
        deck.addCard(cardId: 11111111, to: .side)

        let evaluations = DeckLimitChecker.evaluate(
            deck: deck,
            against: [
                DatedLimitListSnapshot(
                    date: "2026-07-01",
                    snapshot: LimitListSnapshot(forbidden: [:], limited: ["7000": "测试卡"], semiLimited: [:])
                ),
                DatedLimitListSnapshot(
                    date: "2026-04-01",
                    snapshot: LimitListSnapshot(forbidden: [:], limited: [:], semiLimited: ["7000": "测试卡"])
                )
            ],
            referencesByCardID: [
                11111111: DeckLimitCardReference(cardID: 11111111, cid: 7000, name: "测试卡")
            ]
        )

        #expect(evaluations.map(\.date) == ["2026-07-01", "2026-04-01"])
        #expect(evaluations.map(\.outcome) == [.noncompliant, .compliant])
    }

    @Test func datedListsIncludeCurrentAndSortNewestFirst() {
        let emptySnapshot = LimitListSnapshot(forbidden: [:], limited: [:], semiLimited: [:])
        let current = LimitList(
            date: "2026-07-01",
            forbidden: ["1": "当前"],
            limited: [:],
            semiLimited: [:]
        )
        let response = LimitListResponse(
            ja: current,
            cn: current,
            en: current,
            old: LimitListHistory(
                ja: [
                    "2026-01-01": emptySnapshot,
                    "2026-04-01": emptySnapshot
                ],
                cn: [:],
                en: [:]
            )
        )

        #expect(response.datedLists(for: .ocg).map(\.date) == [
            "2026-07-01",
            "2026-04-01",
            "2026-01-01"
        ])
    }
}
