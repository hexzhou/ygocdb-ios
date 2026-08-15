//
//  LimitList.swift
//  ygocdb
//

import Foundation

/// `/api/v0/limits.json` 返回的全部禁限卡表。
struct LimitListResponse: Codable, Equatable {
    let ja: LimitList
    let cn: LimitList
    let en: LimitList
    let old: LimitListHistory?

    func list(for environment: LimitEnvironment) -> LimitList {
        switch environment {
        case .ocg:
            return ja
        case .simplifiedChinese:
            return cn
        case .tcg:
            return en
        }
    }

    func previousList(for environment: LimitEnvironment) -> DatedLimitListSnapshot? {
        let currentDate = list(for: environment).date
        guard let history = old?.lists(for: environment),
              let previousDate = history.keys.filter({ $0 < currentDate }).max(),
              let snapshot = history[previousDate] else {
            return nil
        }

        return DatedLimitListSnapshot(date: previousDate, snapshot: snapshot)
    }

    func changes(for environment: LimitEnvironment) -> [LimitListChange] {
        guard let previous = previousList(for: environment) else { return [] }
        return list(for: environment).changes(from: previous.snapshot)
    }

    /// 当前与历史卡表合并后按日期从新到旧排列。
    func datedLists(for environment: LimitEnvironment) -> [DatedLimitListSnapshot] {
        let current = list(for: environment)
        var snapshots = old?.lists(for: environment) ?? [:]
        snapshots[current.date] = current.snapshot

        return snapshots.map { date, snapshot in
            DatedLimitListSnapshot(date: date, snapshot: snapshot)
        }
        .sorted { $0.date > $1.date }
    }
}

/// 单个对战环境的禁限卡表。
struct LimitList: Codable, Equatable {
    let date: String
    let forbidden: [String: String]
    let limited: [String: String]
    let semiLimited: [String: String]

    enum CodingKeys: String, CodingKey {
        case date, forbidden, limited
        case semiLimited = "semi_limited"
    }

    var totalCount: Int {
        forbidden.count + limited.count + semiLimited.count
    }

    var snapshot: LimitListSnapshot {
        LimitListSnapshot(
            forbidden: forbidden,
            limited: limited,
            semiLimited: semiLimited
        )
    }

    func count(for status: CardLimitStatus) -> Int {
        cards(for: status).count
    }

    func cards(for status: CardLimitStatus) -> [LimitCardEntry] {
        snapshot.cards(for: status)
    }

    func changes(from previous: LimitListSnapshot) -> [LimitListChange] {
        let allCIDs = snapshot.allCIDs.union(previous.allCIDs)

        return allCIDs.compactMap { cid in
            let previousStatus = previous.status(for: cid)
            let currentStatus = snapshot.status(for: cid)
            guard previousStatus != currentStatus else { return nil }

            return LimitListChange(
                cid: cid,
                apiName: snapshot.name(for: cid) ?? previous.name(for: cid) ?? "未知卡片",
                previousStatus: previousStatus,
                currentStatus: currentStatus
            )
        }
        .sorted { lhs, rhs in
            if lhs.direction != rhs.direction {
                return lhs.direction == .tightened
            }
            if lhs.currentAllowedCount != rhs.currentAllowedCount {
                return lhs.currentAllowedCount < rhs.currentAllowedCount
            }
            return lhs.cid < rhs.cid
        }
    }
}

/// 历史卡表按环境、日期保存；日期使用可直接排序的 ISO `yyyy-MM-dd` 格式。
struct LimitListHistory: Codable, Equatable {
    let ja: [String: LimitListSnapshot]
    let cn: [String: LimitListSnapshot]
    let en: [String: LimitListSnapshot]

    func lists(for environment: LimitEnvironment) -> [String: LimitListSnapshot] {
        switch environment {
        case .ocg:
            return ja
        case .simplifiedChinese:
            return cn
        case .tcg:
            return en
        }
    }
}

/// 某一期不含日期字段的卡表快照，日期由 `old` 字典键提供。
struct LimitListSnapshot: Codable, Equatable {
    let forbidden: [String: String]
    let limited: [String: String]
    let semiLimited: [String: String]

    enum CodingKeys: String, CodingKey {
        case forbidden, limited
        case semiLimited = "semi_limited"
    }

    var allCIDs: Set<Int> {
        let keys = Array(forbidden.keys) + Array(limited.keys) + Array(semiLimited.keys)
        return Set(keys.compactMap(Int.init))
    }

    func cards(for status: CardLimitStatus) -> [LimitCardEntry] {
        let source = dictionary(for: status)

        return source.compactMap { cid, name in
            guard let cid = Int(cid) else { return nil }
            return LimitCardEntry(cid: cid, apiName: name, status: status)
        }
        .sorted { lhs, rhs in
            if lhs.cid == rhs.cid {
                return lhs.apiName.localizedStandardCompare(rhs.apiName) == .orderedAscending
            }
            return lhs.cid < rhs.cid
        }
    }

    func status(for cid: Int) -> CardLimitStatus? {
        let key = String(cid)
        if forbidden[key] != nil { return .forbidden }
        if limited[key] != nil { return .limited }
        if semiLimited[key] != nil { return .semiLimited }
        return nil
    }

    func name(for cid: Int) -> String? {
        let key = String(cid)
        return forbidden[key] ?? limited[key] ?? semiLimited[key]
    }

    private func dictionary(for status: CardLimitStatus) -> [String: String] {
        switch status {
        case .forbidden:
            return forbidden
        case .limited:
            return limited
        case .semiLimited:
            return semiLimited
        }
    }
}

struct DatedLimitListSnapshot: Equatable {
    let date: String
    let snapshot: LimitListSnapshot
}

/// 禁限卡表环境。API 使用 `ja` / `cn` / `en`，界面使用玩家更熟悉的名称。
enum LimitEnvironment: String, CaseIterable, Identifiable {
    case ocg
    case simplifiedChinese
    case tcg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ocg:
            return "OCG"
        case .simplifiedChinese:
            return "简中"
        case .tcg:
            return "TCG"
        }
    }

    var fullName: String {
        switch self {
        case .ocg:
            return "OCG 禁限卡表"
        case .simplifiedChinese:
            return "简体中文禁限卡表"
        case .tcg:
            return "TCG 禁限卡表"
        }
    }
}

/// 禁限卡表中的单张卡。`cid` 是官网数据库编号，并非卡片密码。
struct LimitCardEntry: Identifiable, Equatable {
    let cid: Int
    let apiName: String
    let status: CardLimitStatus

    var id: String {
        "\(status.rawValue)-\(cid)"
    }
}

enum LimitChangeDirection: Equatable {
    case tightened
    case relaxed
}

/// 相邻两期卡表中同一 CID 的投入数量变化；`nil` 表示无限制（最多投入 3 张）。
struct LimitListChange: Identifiable, Equatable {
    let cid: Int
    let apiName: String
    let previousStatus: CardLimitStatus?
    let currentStatus: CardLimitStatus?

    var id: Int { cid }

    var previousAllowedCount: Int {
        previousStatus?.rawValue ?? 3
    }

    var currentAllowedCount: Int {
        currentStatus?.rawValue ?? 3
    }

    var direction: LimitChangeDirection {
        currentAllowedCount < previousAllowedCount ? .tightened : .relaxed
    }

    var transitionText: String {
        switch (previousStatus, currentStatus) {
        case (nil, .forbidden):
            return "新禁止"
        case (nil, .limited):
            return "新限制"
        case (nil, .semiLimited):
            return "新准限制"
        case (_, nil):
            return "解除限制"
        case let (previous?, current?):
            return "\(shortName(for: previous)) → \(shortName(for: current))"
        }
    }

    private func shortName(for status: CardLimitStatus) -> String {
        switch status {
        case .forbidden:
            return "禁止"
        case .limited:
            return "限制"
        case .semiLimited:
            return "准限制"
        }
    }
}
