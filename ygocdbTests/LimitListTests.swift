import Foundation
import Testing
@testable import ygocdb

struct LimitListTests {
    @Test func limitListDecodesAllEnvironmentsAndSnakeCaseField() throws {
        let json = """
        {
          "ja": {
            "date": "2026-07-01",
            "forbidden": {"4095": "カタパルト・タートル"},
            "limited": {"4023": "封印されし者の右足"},
            "semi_limited": {"5539": "突然変異"}
          },
          "cn": {
            "date": "2026-07-01",
            "forbidden": {"4426": "魔鬼弗兰肯"},
            "limited": {},
            "semi_limited": {}
          },
          "en": {
            "date": "2026-05-18",
            "forbidden": {"4426": "Cyber-Stein"},
            "limited": {},
            "semi_limited": {}
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LimitListResponse.self, from: json)

        #expect(response.list(for: .ocg).date == "2026-07-01")
        #expect(response.list(for: .ocg).totalCount == 3)
        #expect(response.list(for: .ocg).cards(for: .semiLimited).first?.cid == 5539)
        #expect(response.list(for: .simplifiedChinese).forbidden["4426"] == "魔鬼弗兰肯")
        #expect(response.list(for: .tcg).date == "2026-05-18")
    }

    @Test func limitListIgnoresMalformedCIDKeys() throws {
        let list = LimitList(
            date: "2026-07-01",
            forbidden: ["bad": "无效数据", "4426": "魔鬼弗兰肯"],
            limited: [:],
            semiLimited: [:]
        )

        let entries = list.cards(for: .forbidden)

        #expect(entries.count == 1)
        #expect(entries.first?.cid == 4426)
    }

    @Test func limitListDecodesHistoryAndSelectsNearestPreviousDate() throws {
        let json = """
        {
          "ja": {"date":"2026-07-01","forbidden":{},"limited":{"2":"当前"},"semi_limited":{}},
          "cn": {"date":"2026-07-01","forbidden":{},"limited":{},"semi_limited":{}},
          "en": {"date":"2026-05-18","forbidden":{},"limited":{},"semi_limited":{}},
          "old": {
            "ja": {
              "2026-01-01":{"forbidden":{},"limited":{},"semi_limited":{}},
              "2026-04-01":{"forbidden":{"2":"上一期"},"limited":{},"semi_limited":{}}
            },
            "cn": {},
            "en": {}
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LimitListResponse.self, from: json)
        let previous = response.previousList(for: .ocg)
        let changes = response.changes(for: .ocg)

        #expect(previous?.date == "2026-04-01")
        #expect(changes.count == 1)
        #expect(changes.first?.previousStatus == .forbidden)
        #expect(changes.first?.currentStatus == .limited)
        #expect(changes.first?.direction == .relaxed)
        #expect(changes.first?.transitionText == "禁止 → 限制")
    }

    @Test func limitListDiffIncludesNewRestrictionsAndReleasedCards() {
        let previous = LimitListSnapshot(
            forbidden: ["1": "A"],
            limited: ["2": "B"],
            semiLimited: ["3": "C"]
        )
        let current = LimitList(
            date: "2026-07-01",
            forbidden: ["2": "B", "4": "D"],
            limited: ["1": "A"],
            semiLimited: ["5": "E"]
        )

        let changes = current.changes(from: previous)
        let byCID = Dictionary(uniqueKeysWithValues: changes.map { ($0.cid, $0) })

        #expect(changes.count == 5)
        #expect(byCID[2]?.transitionText == "限制 → 禁止")
        #expect(byCID[4]?.transitionText == "新禁止")
        #expect(byCID[5]?.transitionText == "新准限制")
        #expect(byCID[1]?.direction == .relaxed)
        #expect(byCID[3]?.transitionText == "解除限制")
        #expect(byCID[3]?.currentAllowedCount == 3)
    }

    @Test @MainActor func currentChangesAppearBeforeUnchangedCardsWithinASection() {
        let current = LimitList(
            date: "2026-07-01",
            forbidden: ["5": "未变化 5", "10": "未变化 10", "20": "新禁止", "30": "限制变禁止"],
            limited: [:],
            semiLimited: [:]
        )
        let previous = LimitListSnapshot(
            forbidden: ["5": "未变化 5", "10": "未变化 10"],
            limited: ["30": "限制变禁止"],
            semiLimited: [:]
        )
        let empty = LimitList(date: "2026-07-01", forbidden: [:], limited: [:], semiLimited: [:])
        let response = LimitListResponse(
            ja: current,
            cn: empty,
            en: empty,
            old: LimitListHistory(
                ja: ["2026-04-01": previous],
                cn: [:],
                en: [:]
            )
        )

        let viewModel = LimitListViewModel(response: response)
        let cids = viewModel.entries(for: .forbidden).map(\.cid)

        #expect(cids == [20, 30, 5, 10])
    }
}
