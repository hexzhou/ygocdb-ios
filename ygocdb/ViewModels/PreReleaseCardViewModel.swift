//
//  PreReleaseCardViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/13.
//

import Foundation
import Combine

/// 先行卡视图模型
@MainActor
class PreReleaseCardViewModel: ObservableObject {
    @Published var cards: [PreReleaseCard] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published private(set) var idChangelog: [Int: Int] = [:]
    
    /// 过滤后的卡片（排除已在全卡数据中存在的卡片）
    var filteredCards: [PreReleaseCard] {
        // 首先过滤掉已在全卡数据中存在的卡片
        let uniqueCards = cards.filter { card in
            idChangelog[card.id] == nil
        }

        if searchText.isEmpty {
            return uniqueCards
        }

        let query = searchText.lowercased()
        return uniqueCards.filter { card in
            card.name.lowercased().contains(query) ||
            card.desc.lowercased().contains(query) ||
            String(card.id).contains(searchText)
        }
    }
    
    /// 新增卡片数量
    var newCardsCount: Int {
        cards.filter { $0.created }.count
    }
    
    /// 更新卡片数量
    var updatedCardsCount: Int {
        cards.filter { $0.updated }.count
    }
    
    /// 加载先行卡列表
    func loadCards(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            cards = try await PreReleaseCardService.shared.fetchCards(forceRefresh: forceRefresh)
            idChangelog = await CardIDChangelogService.shared.getCachedMappings()
        } catch {
            if error.isTaskCancellation || Task.isCancelled {
                isLoading = false
                return
            }

            idChangelog = await CardIDChangelogService.shared.getCachedMappings()
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    /// 刷新数据
    func refresh() async {
        await loadCards(forceRefresh: true)
    }
}
