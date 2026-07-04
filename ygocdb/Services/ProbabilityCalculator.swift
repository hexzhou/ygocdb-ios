//
//  ProbabilityCalculator.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/30.
//

import Foundation

enum ProbabilityCalculationError: LocalizedError {
    case emptyDeck
    case invalidDraws
    case invalidCondition(String)
    case invalidGroups(String)

    var errorDescription: String? {
        switch self {
        case .emptyDeck:
            return "主卡组为空"
        case .invalidDraws:
            return "抽卡数量超过主卡组总数"
        case .invalidCondition(let message):
            return "条件表达式错误：\(message)"
        case .invalidGroups(let message):
            return "分组设置错误：\(message)"
        }
    }
}

struct ProbabilityCalculationOutput {
    let probability: Double
    let methodUsed: ProbabilityCalculationMethod
    let isApproximate: Bool
}

enum ProbabilityCalculator {
    // MARK: - Public

    static func calculateBase(
        deckCounts: [Int: Int],
        deckSize: Int,
        groups: [ProbabilityGroup],
        scenario: ProbabilityScenario
    ) throws -> ProbabilityCalculationOutput {
        let groupCounts = try buildGroupCounts(deckCounts: deckCounts, deckSize: deckSize, groups: groups)
        guard scenario.draws > 0 && scenario.draws <= deckSize else {
            throw ProbabilityCalculationError.invalidDraws
        }

        let conditionFunc = try ProbabilityCondition.compile(
            expression: scenario.condition,
            maxGroupCount: groups.count
        )

        let method = chooseMethod(scenario: scenario, deckSize: deckSize, groupCount: groups.count)
        switch method {
        case .exact:
            let probability = calculateExact(
                cardCounts: groupCounts,
                draws: scenario.draws,
                groupCount: groups.count,
                condition: conditionFunc
            )
            return ProbabilityCalculationOutput(probability: probability, methodUsed: .exact, isApproximate: false)
        case .monteCarlo:
            let probability = calculateMonteCarlo(
                cardCounts: groupCounts,
                draws: scenario.draws,
                groupCount: groups.count,
                simulations: scenario.simulations,
                condition: conditionFunc
            )
            return ProbabilityCalculationOutput(probability: probability, methodUsed: .monteCarlo, isApproximate: true)
        case .auto:
            return ProbabilityCalculationOutput(probability: 0, methodUsed: .auto, isApproximate: true)
        }
    }

    // MARK: - Core Calculation

    private static func calculateProbabilityForCounts(
        deckCounts: [Int: Int],
        deckSize: Int,
        groups: [ProbabilityGroup],
        scenario: ProbabilityScenario,
        condition: @escaping ([Int]) -> Bool
    ) -> Double {
        guard let groupCounts = try? buildGroupCounts(deckCounts: deckCounts, deckSize: deckSize, groups: groups) else {
            return 0
        }
        let method = chooseMethod(scenario: scenario, deckSize: deckSize, groupCount: groups.count)
        switch method {
        case .exact:
            return calculateExact(
                cardCounts: groupCounts,
                draws: scenario.draws,
                groupCount: groups.count,
                condition: condition
            )
        case .monteCarlo:
            return calculateMonteCarlo(
                cardCounts: groupCounts,
                draws: scenario.draws,
                groupCount: groups.count,
                simulations: scenario.simulations,
                condition: condition
            )
        case .auto:
            return calculateMonteCarlo(
                cardCounts: groupCounts,
                draws: scenario.draws,
                groupCount: groups.count,
                simulations: scenario.simulations,
                condition: condition
            )
        }
    }

    private static func chooseMethod(
        scenario: ProbabilityScenario,
        deckSize: Int,
        groupCount: Int
    ) -> ProbabilityCalculationMethod {
        switch scenario.method {
        case .auto:
            let useExact = deckSize <= 40 && groupCount <= 10 && scenario.draws <= 6
            return useExact ? .exact : .monteCarlo
        default:
            return scenario.method
        }
    }

    private static func calculateExact(
        cardCounts: [Int],
        draws: Int,
        groupCount: Int,
        condition: @escaping ([Int]) -> Bool
    ) -> Double {
        if cardCounts.reduce(0, +) < draws { return 0 }

        var valid = 0.0
        var total = 0.0

        func recurse(index: Int, remaining: Int, current: inout [Int]) {
            if index == cardCounts.count {
                if remaining != 0 { return }
                var ways = 1.0
                for i in 0..<cardCounts.count {
                    ways *= combination(n: cardCounts[i], k: current[i])
                }
                total += ways
                if condition(Array(current.prefix(groupCount))) {
                    valid += ways
                }
                return
            }

            let maxTake = min(cardCounts[index], remaining)
            for k in 0...maxTake {
                current[index] = k
                recurse(index: index + 1, remaining: remaining - k, current: &current)
            }
        }

        var counts = Array(repeating: 0, count: cardCounts.count)
        recurse(index: 0, remaining: draws, current: &counts)

        guard total > 0 else { return 0 }
        return (valid / total) * 100
    }

    private static func calculateMonteCarlo(
        cardCounts: [Int],
        draws: Int,
        groupCount: Int,
        simulations: Int,
        condition: @escaping ([Int]) -> Bool
    ) -> Double {
        let totalCards = cardCounts.reduce(0, +)
        if totalCards < draws || totalCards == 0 { return 0 }

        var deck: [Int] = []
        deck.reserveCapacity(totalCards)
        for (index, count) in cardCounts.enumerated() {
            if count > 0 {
                deck.append(contentsOf: Array(repeating: index, count: count))
            }
        }

        var valid = 0
        for _ in 0..<simulations {
            deck.shuffle()
            var counts = Array(repeating: 0, count: groupCount)
            for i in 0..<draws {
                let type = deck[i]
                if type < groupCount {
                    counts[type] += 1
                }
            }
            if condition(counts) {
                valid += 1
            }
        }

        return (Double(valid) / Double(simulations)) * 100
    }

    // MARK: - Helpers

    private static func buildGroupCounts(
        deckCounts: [Int: Int],
        deckSize: Int,
        groups: [ProbabilityGroup]
    ) throws -> [Int] {
        if deckSize == 0 {
            throw ProbabilityCalculationError.emptyDeck
        }

        var usedCardIds = Set<Int>()
        for group in groups {
            for cardId in group.cardIds {
                if usedCardIds.contains(cardId) {
                    throw ProbabilityCalculationError.invalidGroups("同一张卡不能属于多个分组")
                }
                usedCardIds.insert(cardId)
            }
        }

        var groupCounts: [Int] = []
        var totalGroupCount = 0
        for group in groups {
            let count = group.cardIds.reduce(0) { $0 + (deckCounts[$1] ?? 0) }
            groupCounts.append(count)
            totalGroupCount += count
        }

        if totalGroupCount > deckSize {
            throw ProbabilityCalculationError.invalidGroups("分组卡片数量超过主卡组总数")
        }

        let others = deckSize - totalGroupCount
        groupCounts.append(others)
        return groupCounts
    }

    private static func combination(n: Int, k: Int) -> Double {
        if k < 0 || k > n { return 0 }
        if k == 0 || k == n { return 1 }
        let k = min(k, n - k)
        var result = 1.0
        for i in 1...k {
            result *= Double(n - k + i) / Double(i)
        }
        return result
    }

}

// MARK: - Condition Parser

enum ProbabilityCondition {
    struct SingleCondition {
        var cards: [ConditionCard]
        var symbol: CompareSymbol
        var value: Double
    }

    struct ConditionCard {
        var name: String
        var op: ArithmeticOp?
    }

    enum CompareSymbol {
        case gt, lt, eq, neq, gte, lte
    }

    enum ArithmeticOp: String {
        case add = "+"
        case sub = "-"
    }

    indirect enum Node {
        case single(SingleCondition)
        case and([Node])
        case or([Node])
    }

    static func compile(expression: String, maxGroupCount: Int) throws -> ([Int]) -> Bool {
        let node = try parse(expression: expression)
        try validate(node: node, maxGroupCount: maxGroupCount)
        return { counts in
            evaluate(node: node, counts: counts)
        }
    }

    private static func parse(expression: String) throws -> Node {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProbabilityCalculationError.invalidCondition("表达式为空")
        }

        let tokens = try tokenize(trimmed)
        var parser = Parser(tokens: tokens)
        let node = try parseExpression(&parser)
        if !parser.isAtEnd {
            throw ProbabilityCalculationError.invalidCondition("无法解析表达式")
        }
        if case .single = node {
            return .and([node])
        }
        return flatten(node)
    }

    private static func tokenize(_ expression: String) throws -> [String] {
        let pattern = "\\s*([A-Za-z0-9_]+|>=|<=|==|!=|&&|\\|\\||[-+()<>])\\s*"
        let regex = try NSRegularExpression(pattern: pattern)
        let nsExpression = expression as NSString
        let matches = regex.matches(in: expression, range: NSRange(location: 0, length: nsExpression.length))

        var tokens: [String] = []
        var lastIndex = 0
        for match in matches {
            let range = match.range(at: 1)
            if range.location > lastIndex {
                let skipped = nsExpression.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex)).trimmingCharacters(in: .whitespaces)
                if !skipped.isEmpty {
                    throw ProbabilityCalculationError.invalidCondition("不支持的字符: \(skipped)")
                }
            }
            let token = nsExpression.substring(with: range)
            tokens.append(token)
            lastIndex = range.location + range.length
        }
        if lastIndex < nsExpression.length {
            let remaining = nsExpression.substring(from: lastIndex).trimmingCharacters(in: .whitespaces)
            if !remaining.isEmpty {
                throw ProbabilityCalculationError.invalidCondition("不支持的字符: \(remaining)")
            }
        }
        return tokens
    }

    private struct Parser {
        let tokens: [String]
        var index: Int = 0

        var isAtEnd: Bool { index >= tokens.count }

        func peek() -> String? {
            guard index < tokens.count else { return nil }
            return tokens[index]
        }

        mutating func consume(_ expected: String? = nil) throws -> String {
            guard index < tokens.count else {
                throw ProbabilityCalculationError.invalidCondition("表达式结束")
            }
            let token = tokens[index]
            if let expected = expected, token != expected {
                throw ProbabilityCalculationError.invalidCondition("预期 \(expected) 但得到 \(token)")
            }
            index += 1
            return token
        }
    }

    private static func parseExpression(_ parser: inout Parser) throws -> Node {
        return try parseLogicalOr(&parser)
    }

    private static func parseLogicalOr(_ parser: inout Parser) throws -> Node {
        var node = try parseLogicalAnd(&parser)
        while let peek = parser.peek(), peek == "||" {
            _ = try parser.consume("||")
            let right = try parseLogicalAnd(&parser)
            node = .or([node, right])
        }
        return node
    }

    private static func parseLogicalAnd(_ parser: inout Parser) throws -> Node {
        var node = try parseRelational(&parser)
        while let peek = parser.peek(), peek == "&&" {
            _ = try parser.consume("&&")
            let right = try parseRelational(&parser)
            node = .and([node, right])
        }
        return node
    }

    private static func parseRelational(_ parser: inout Parser) throws -> Node {
        let left = try parseSum(&parser)

        if case .node(let conditionNode) = left {
            return conditionNode
        }

        guard let op = parser.peek(), [">", "<", ">=", "<=", "==", "!="].contains(op) else {
            throw ProbabilityCalculationError.invalidCondition("缺少比较运算符")
        }
        _ = try parser.consume()
        let numToken = try parser.consume()
        guard let number = Double(numToken) else {
            throw ProbabilityCalculationError.invalidCondition("比较值必须是数字")
        }

        let cards = try buildCards(from: left)
        let symbol = mapCompare(op)
        return .single(SingleCondition(cards: cards, symbol: symbol, value: number))
    }

    private enum SumResult {
        case tokens([String])
        case node(Node)
    }

    private static func parseSum(_ parser: inout Parser) throws -> SumResult {
        if parser.peek() == "(" {
            _ = try parser.consume("(")
            let startIndex = parser.index
            if let node = try? parseExpression(&parser) {
                if parser.peek() == ")" {
                    _ = try parser.consume(")")
                    return .node(node)
                }
            }
            parser.index = startIndex
            var tokens: [String] = []
            tokens.append(try parser.consume())
            while let peek = parser.peek(), ["+", "-"].contains(peek) {
                tokens.append(try parser.consume())
                tokens.append(try parser.consume())
            }
            _ = try parser.consume(")")
            return .tokens(tokens)
        }

        var tokens: [String] = []
        tokens.append(try parser.consume())
        while let peek = parser.peek(), ["+", "-"].contains(peek) {
            tokens.append(try parser.consume())
            tokens.append(try parser.consume())
        }
        return .tokens(tokens)
    }

    private static func buildCards(from result: SumResult) throws -> [ConditionCard] {
        guard case .tokens(let tokens) = result else {
            throw ProbabilityCalculationError.invalidCondition("表达式无法解析")
        }
        guard !tokens.isEmpty else {
            throw ProbabilityCalculationError.invalidCondition("表达式为空")
        }
        var cards: [ConditionCard] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if index == 0 {
                cards.append(ConditionCard(name: token, op: nil))
                index += 1
                continue
            }
            guard index + 1 < tokens.count else {
                throw ProbabilityCalculationError.invalidCondition("表达式不完整")
            }
            let opToken = token
            let operand = tokens[index + 1]
            guard let op = ArithmeticOp(rawValue: opToken) else {
                throw ProbabilityCalculationError.invalidCondition("不支持的运算符: \(opToken)")
            }
            cards.append(ConditionCard(name: operand, op: op))
            index += 2
        }
        return cards
    }

    private static func mapCompare(_ op: String) -> CompareSymbol {
        switch op {
        case ">": return .gt
        case "<": return .lt
        case "==": return .eq
        case "!=": return .neq
        case ">=": return .gte
        default: return .lte
        }
    }

    private static func evaluate(node: Node, counts: [Int]) -> Bool {
        switch node {
        case .single(let condition):
            let value = evaluateSingle(condition, counts: counts)
            switch condition.symbol {
            case .gt: return value > condition.value
            case .lt: return value < condition.value
            case .eq: return value == condition.value
            case .neq: return value != condition.value
            case .gte: return value >= condition.value
            case .lte: return value <= condition.value
            }
        case .and(let children):
            return children.allSatisfy { evaluate(node: $0, counts: counts) }
        case .or(let children):
            return children.contains { evaluate(node: $0, counts: counts) }
        }
    }

    private static func evaluateSingle(_ condition: SingleCondition, counts: [Int]) -> Double {
        var value: Double = 0
        for (index, card) in condition.cards.enumerated() {
            let count = Double(counts[safe: varToIndex(card.name) ?? -1] ?? 0)
            if index == 0 {
                value = count
            } else if let op = card.op {
                switch op {
                case .add: value += count
                case .sub: value -= count
                }
            }
        }
        return value
    }

    private static func validate(node: Node, maxGroupCount: Int) throws {
        let variables = extractVariables(from: node)
        for variable in variables {
            guard let index = varToIndex(variable) else {
                throw ProbabilityCalculationError.invalidCondition("无效变量: \(variable)")
            }
            if index >= maxGroupCount {
                throw ProbabilityCalculationError.invalidCondition("变量 \(variable) 未定义")
            }
        }
    }

    private static func extractVariables(from node: Node) -> Set<String> {
        switch node {
        case .single(let condition):
            return Set(condition.cards.map { $0.name })
        case .and(let children), .or(let children):
            return children.reduce(into: Set<String>()) { result, child in
                result.formUnion(extractVariables(from: child))
            }
        }
    }

    private static func varToIndex(_ varName: String) -> Int? {
        let name = varName.lowercased()
        if name.count == 1, let ascii = name.unicodeScalars.first?.value {
            let index = Int(ascii) - 97
            if index >= 0 && index < 26 { return index }
        }
        if name.count == 2, name.hasPrefix("a"), let second = name.unicodeScalars.last?.value {
            let index = 26 + Int(second) - 97
            if index >= 26 && index < 30 { return index }
        }
        return nil
    }

    private static func flatten(_ node: Node) -> Node {
        switch node {
        case .single:
            return node
        case .and(let children):
            var flat: [Node] = []
            for child in children {
                let normalized = flatten(child)
                if case .and(let nested) = normalized {
                    flat.append(contentsOf: nested)
                } else {
                    flat.append(normalized)
                }
            }
            return .and(flat)
        case .or(let children):
            var flat: [Node] = []
            for child in children {
                let normalized = flatten(child)
                if case .or(let nested) = normalized {
                    flat.append(contentsOf: nested)
                } else {
                    flat.append(normalized)
                }
            }
            return .or(flat)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
