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
    
    /// 过滤后的卡片
    var filteredCards: [PreReleaseCard] {
        if searchText.isEmpty {
            return cards
        }
        
        let query = searchText.lowercased()
        return cards.filter { card in
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
        } catch {
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
