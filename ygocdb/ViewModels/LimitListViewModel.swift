//
//  LimitListViewModel.swift
//  ygocdb
//

import Foundation
import Combine

@MainActor
final class LimitListViewModel: ObservableObject {
    @Published private(set) var response: LimitListResponse?
    @Published var selectedEnvironment: LimitEnvironment = .ocg
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showRefreshError = false

    private let statuses: [CardLimitStatus] = [.forbidden, .limited, .semiLimited]

    init(response: LimitListResponse? = nil) {
        self.response = response
    }

    var selectedList: LimitList? {
        response?.list(for: selectedEnvironment)
    }

    var changes: [LimitListChange] {
        response?.changes(for: selectedEnvironment) ?? []
    }

    var visibleStatuses: [CardLimitStatus] {
        statuses.filter { !entries(for: $0).isEmpty }
    }

    var hasSearchResults: Bool {
        !visibleStatuses.isEmpty
    }

    func entries(for status: CardLimitStatus) -> [LimitCardEntry] {
        guard let entries = selectedList?.cards(for: status) else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredEntries: [LimitCardEntry]

        if query.isEmpty {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter { entry in
                if entry.apiName.lowercased().contains(query) || String(entry.cid).contains(query) {
                    return true
                }

                guard let card = CardRepository.shared.getCard(byCID: entry.cid) else {
                    return false
                }

                let names = [
                    card.cnName,
                    card.scName,
                    card.mdName,
                    card.nwbbsN,
                    card.cnocgN,
                    card.jpName,
                    card.jpRuby,
                    card.enName,
                    card.id > 0 ? String(card.id) : nil
                ]

                return names.compactMap { $0?.lowercased() }.contains { $0.contains(query) }
            }
        }

        return entriesOrderedByChanges(filteredEntries)
    }

    private func entriesOrderedByChanges(_ entries: [LimitCardEntry]) -> [LimitCardEntry] {
        let changeOrderByCID = Dictionary(
            uniqueKeysWithValues: changes.enumerated().map { ($0.element.cid, $0.offset) }
        )

        return entries.sorted { lhs, rhs in
            switch (changeOrderByCID[lhs.cid], changeOrderByCID[rhs.cid]) {
            case let (lhsOrder?, rhsOrder?):
                return lhsOrder < rhsOrder
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                if lhs.cid == rhs.cid {
                    return lhs.apiName.localizedStandardCompare(rhs.apiName) == .orderedAscending
                }
                return lhs.cid < rhs.cid
            }
        }
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
            showRefreshError = response != nil
        }

        isLoading = false
    }

    func refresh() async {
        await load(forceRefresh: true)
    }
}
