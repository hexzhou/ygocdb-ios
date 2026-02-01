//
//  DeckCardSearchView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import SwiftUI

/// 搜索模式
enum CardSearchMode: String, CaseIterable {
    case normal = "正式卡"
    case preRelease = "先行卡"
}

/// 卡组搜索添加卡片视图
struct DeckCardSearchView: View {
    let deck: Deck
    @ObservedObject var viewModel: DeckBuilderViewModel
    @ObservedObject var searchViewModel: CardSearchViewModel
    @ObservedObject var filter: CardFilter
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var preReleaseViewModel = PreReleaseCardViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showFilter = false
    @State private var toastMessage: String?
    @State private var searchMode: CardSearchMode = .normal

    /// 每页显示数量
    private let pageSize = 100
    @State private var displayCount = 100

    /// 判断卡片是否为额外卡组卡片（融合、同调、超量、连接、灵摆怪兽）
    private func isExtraDeckCard(_ card: Card) -> Bool {
        guard let type = card.data?.type else { return false }
        // 检查是否为融合(0x40)、同调(0x2000)、超量(0x800000)、连接(0x4000000)
        return (type & 0x40) != 0 || (type & 0x2000) != 0 || (type & 0x800000) != 0 || (type & 0x4000000) != 0
    }

    /// 基础数据源（正式卡）
    var baseCards: [Card] {
        if searchViewModel.searchText.isEmpty {
            if filter.hasActiveFilters {
                return CardRepository.shared.getAllCards()
            } else {
                return []
            }
        } else {
            return searchViewModel.searchResults
        }
    }

    /// 应用筛选后的结果（正式卡）
    var filteredResults: [Card] {
        filter.apply(to: baseCards)
    }

    /// 当前显示的卡片（正式卡）
    var displayedCards: [Card] {
        Array(filteredResults.prefix(displayCount))
    }

    /// 是否还有更多（正式卡）
    var hasMore: Bool {
        displayCount < filteredResults.count
    }

    /// 先行卡过滤结果（排除已在全卡数据中存在的卡片）
    var filteredPreReleaseCards: [PreReleaseCard] {
        preReleaseViewModel.filteredCards.filter { card in
            // 如果全卡数据中已有该 ID 的卡片，则不显示在先行卡列表中
            CardRepository.shared.getCard(byId: card.id) == nil
        }
    }

    /// 当前显示的先行卡
    var displayedPreReleaseCards: [PreReleaseCard] {
        Array(filteredPreReleaseCards.prefix(displayCount))
    }

    /// 是否还有更多先行卡
    var hasMorePreRelease: Bool {
        displayCount < filteredPreReleaseCards.count
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 模式选择器
                Picker("搜索模式", selection: $searchMode) {
                    ForEach(CardSearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 列表内容
                if searchMode == .normal {
                    normalCardListView
                } else {
                    preReleaseCardListView
                }
            }
            .navigationTitle("添加卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if searchMode == .normal {
                        Button {
                            showFilter = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                Text("筛选")
                                    .font(.caption)
                            }
                            .foregroundColor(filter.hasActiveFilters ? .blue : .primary)
                        }
                    }
                }
            }
            .searchable(
                text: searchMode == .normal ? $searchViewModel.searchText : $preReleaseViewModel.searchText,
                prompt: searchMode == .normal ? "搜索正式卡..." : "搜索先行卡..."
            )
            .sheet(isPresented: $showFilter) {
                CardFilterView(filter: filter)
            }
            .onChange(of: searchViewModel.searchText) { _ in
                displayCount = pageSize
            }
            .onChange(of: preReleaseViewModel.searchText) { _ in
                displayCount = pageSize
            }
            .onChange(of: searchMode) { _ in
                displayCount = pageSize
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
            .overlay(
                VStack {
                    Spacer()
                    if let message = toastMessage {
                        ToastView(message: message)
                            .padding(.bottom, 50)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: toastMessage)
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            // 预加载先行卡数据
            await preReleaseViewModel.loadCards()
        }
    }

    // MARK: - 正式卡列表

    private var normalCardListView: some View {
        List {
            if filteredResults.isEmpty {
                EmptyStateRow(
                    searchText: searchViewModel.searchText,
                    hasActiveFilters: filter.hasActiveFilters
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(displayedCards) { card in
                    HStack(spacing: 12) {
                        // 卡片信息
                        NavigationLink(destination: CardDetailView(card: card)) {
                            CompactCardRow(card: card, settings: settings)
                        }

                        // 添加按钮区域
                        VStack(spacing: 8) {
                            // 主卡组/额外卡组按钮
                            Button {
                                let deckType: DeckType = isExtraDeckCard(card) ? .extra : .main
                                addCardToDeck(card, deckType: deckType)
                            } label: {
                                Text(isExtraDeckCard(card) ? "额外+1" : "主卡+1")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(minWidth: 72)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            // 副卡组按钮
                            Button {
                                addCardToDeck(card, deckType: .side)
                            } label: {
                                Text("副卡+1")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(minWidth: 72)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if hasMore {
                    Button {
                        displayCount += pageSize
                    } label: {
                        Text("加载更多 (\(filteredResults.count - displayCount) 张)")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowSeparator(.hidden)
                }

                Text("共 \(filteredResults.count) 张卡片")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 先行卡列表

    private var preReleaseCardListView: some View {
        List {
            if preReleaseViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("加载先行卡...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if filteredPreReleaseCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    if preReleaseViewModel.searchText.isEmpty {
                        Text("暂无先行卡数据")
                            .font(.headline)
                        Text("请检查网络连接后重试")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("未找到匹配的先行卡")
                            .font(.headline)
                        Text("尝试使用其他关键词搜索")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowSeparator(.hidden)
            } else {
                ForEach(displayedPreReleaseCards) { card in
                    HStack(spacing: 12) {
                        // 卡片信息（可点击查看详情）
                        NavigationLink(destination: PreReleaseCardDetailView(card: card)) {
                            PreReleaseCardRowCompact(card: card)
                        }

                        // 添加按钮区域
                        VStack(spacing: 8) {
                            // 主卡组/额外卡组按钮（根据卡片类型判断）
                            Button {
                                let deckType: DeckType = card.isExtraDeckCard ? .extra : .main
                                addPreReleaseCardToDeck(card, deckType: deckType)
                            } label: {
                                Text(card.isExtraDeckCard ? "额外+1" : "主卡+1")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(minWidth: 72)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            // 副卡组按钮
                            Button {
                                addPreReleaseCardToDeck(card, deckType: .side)
                            } label: {
                                Text("副卡+1")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(minWidth: 72)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if hasMorePreRelease {
                    Button {
                        displayCount += pageSize
                    } label: {
                        Text("加载更多 (\(filteredPreReleaseCards.count - displayCount) 张)")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowSeparator(.hidden)
                }

                Text("共 \(filteredPreReleaseCards.count) 张先行卡")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await preReleaseViewModel.refresh()
        }
    }

    // MARK: - 辅助方法

    /// 添加正式卡到卡组
    private func addCardToDeck(_ card: Card, deckType: DeckType) {
        let result = viewModel.addCard(cardId: card.id, to: deckType, in: deck)
        switch result {
        case .success:
            let deckTypeName = deckType.rawValue
            showToast("已添加到\(deckTypeName)")
        case .limitReached:
            showToast("每张卡片最多只能添加3张")
        case .deckFull, .failed:
            break
        }
    }

    /// 添加先行卡到卡组
    private func addPreReleaseCardToDeck(_ card: PreReleaseCard, deckType: DeckType) {
        let result = viewModel.addCard(cardId: card.id, to: deckType, in: deck)
        switch result {
        case .success:
            let deckTypeName = deckType.rawValue
            showToast("已添加到\(deckTypeName)")
        case .limitReached:
            showToast("每张卡片最多只能添加3张")
        case .deckFull, .failed:
            break
        }
    }

    /// 显示 Toast
    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

// MARK: - 先行卡紧凑行视图

struct PreReleaseCardRowCompact: View {
    let card: PreReleaseCard
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            // 卡图
            CachedAsyncImage(
                url: card.imageURL,
                cacheKey: "prerelease-compact-\(card.id)"
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(ProgressView())
            }
            .frame(width: 50, height: 73)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // 卡片信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(card.name)
                        .font(.body)
                        .lineLimit(1)

                    // 状态标签
                    if let statusLabel = card.statusLabel {
                        Text(statusLabel)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(card.created ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(card.overallString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }
}

#Preview {
    DeckCardSearchView(
        deck: Deck(name: "测试卡组"),
        viewModel: DeckBuilderViewModel(),
        searchViewModel: CardSearchViewModel(),
        filter: CardFilter()
    )
}
