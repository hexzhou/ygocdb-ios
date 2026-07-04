//
//  ygocdbTests.swift
//  ygocdbTests
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import Testing
@testable import ygocdb

struct ygocdbTests {

    @Test func probabilityAdditionConditionCalculates() throws {
        let scenario = ProbabilityScenario(
            name: "A or B",
            condition: "a + b >= 1",
            groups: [
                ProbabilityGroup(label: "A", name: "A", cardIds: [1]),
                ProbabilityGroup(label: "B", name: "B", cardIds: [2])
            ]
        )

        let result = try ProbabilityCalculator.calculateBase(
            deckCounts: [1: 3, 2: 3],
            deckSize: 40,
            groups: scenario.groups,
            scenario: scenario
        )

        #expect(result.probability > 0)
        #expect(result.methodUsed == .exact)
    }

    @Test func probabilityRejectsUnsupportedMultiplication() {
        let scenario = ProbabilityScenario(
            name: "Unsupported",
            condition: "a * b > 0",
            groups: [
                ProbabilityGroup(label: "A", name: "A", cardIds: [1]),
                ProbabilityGroup(label: "B", name: "B", cardIds: [2])
            ]
        )

        let result = try? ProbabilityCalculator.calculateBase(
            deckCounts: [1: 3, 2: 3],
            deckSize: 40,
            groups: scenario.groups,
            scenario: scenario
        )

        #expect(result == nil)
    }

    @MainActor
    @Test func base64ImportRejectsUnknownCardMetadata() {
        let code = base64DeckCode(mainAndExtra: [2_147_483_647], side: [])
        #expect(Deck.importFromCode(code, name: "Imported") == nil)
    }

    @Test func preReleaseCardDecodesMissingStatusFlags() throws {
        let json = """
        {
            "id": 100262101,
            "name": "测试先行卡",
            "desc": "效果文本",
            "overallString": "[怪兽|效果]",
            "picUrl": "https://example.com/card.jpg",
            "createTime": 1783082403,
            "createCommit": "abc",
            "updateTime": 1783086440,
            "updateCommit": "def"
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(PreReleaseCard.self, from: json)

        #expect(card.created == false)
        #expect(card.updated == false)
    }

    @Test func idChangelogParsesMirrorJSONPFormat() throws {
        let mappings = try CardIDChangelogService.parseMappings(
            from: "/**/ typeof callback === 'function' && callback({\"100200002\":23923758,\"bad\":1});"
        )

        #expect(mappings[100200002] == 23923758)
        #expect(mappings.count == 1)
    }

    private func base64DeckCode(mainAndExtra: [Int32], side: [Int32]) -> String {
        var data = Data()
        append(Int32(mainAndExtra.count), to: &data)
        append(Int32(side.count), to: &data)
        for cardId in mainAndExtra {
            append(cardId, to: &data)
        }
        for cardId in side {
            append(cardId, to: &data)
        }
        return data.base64EncodedString()
    }

    private func append(_ value: Int32, to data: inout Data) {
        let raw = UInt32(bitPattern: value)
        data.append(UInt8(raw & 0xFF))
        data.append(UInt8((raw >> 8) & 0xFF))
        data.append(UInt8((raw >> 16) & 0xFF))
        data.append(UInt8((raw >> 24) & 0xFF))
    }

}
