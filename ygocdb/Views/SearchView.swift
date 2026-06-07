//
//  SearchView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

/// 主搜索界面
struct SearchView: View {
    @StateObject private var viewModel = CardSearchViewModel()
    @StateObject private var filter = CardFilter()
    @State private var showSettings = false
    @State private var showPreReleaseCards = false
    @State private var showFilter = false
    
    var body: some View {
        NavigationView {
            Group {
                if !viewModel.hasLocalData && !viewModel.isDataLoaded {
                    // 首次使用，需要下载数据
                    DownloadPromptView(viewModel: viewModel)
                } else if viewModel.isDownloading {
                    // 正在下载
                    DownloadProgressView(progress: viewModel.downloadProgress, phase: viewModel.downloadPhase)
                } else {
                    // 搜索界面
                    CardSearchContentView(viewModel: viewModel, filter: filter, showFilter: $showFilter)
                }
            }
            .navigationTitle("游戏王查卡器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // 先行卡按钮
                        Button {
                            showPreReleaseCards = true
                        } label: {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                        }

                        // 设置按钮
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPreReleaseCards) {
                PreReleaseCardListView()
            }
            .sheet(isPresented: $showFilter) {
                CardFilterView(filter: filter)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                // 加载本地数据
                if viewModel.hasLocalData {
                    await viewModel.loadLocalData()
                }
                // 自动更新检查（由时间间隔策略控制）
                await viewModel.performAutoUpdateCheckIfNeeded()
            }
            .alert("发现新版本", isPresented: $viewModel.showUpdateAvailableAlert) {
                Button("稍后再说", role: .cancel) {}
                Button("立即更新") {
                    Task { await viewModel.downloadAllCards() }
                }
            } message: {
                Text("卡片数据库有新版本可用，是否立即下载更新？")
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .modifier(SearchTabBarModifier(isSearching: !viewModel.searchText.isEmpty))
    }
}

/// 下载提示视图
struct DownloadPromptView: View {
    @ObservedObject var viewModel: CardSearchViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("欢迎使用游戏王查卡器")
                .font(.title)
                .fontWeight(.bold)
            
            Text("首次使用需要下载全卡数据库\n（约 10MB）")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await viewModel.downloadAllCards()
                }
            } label: {
                Label("下载卡片数据", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// 下载进度视图
struct DownloadProgressView: View {
    let progress: Double
    let phase: DownloadPhase
    
    init(progress: Double, phase: DownloadPhase = .downloading) {
        self.progress = progress
        self.phase = phase
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)
                .padding(.horizontal, 40)
            
            Text(phase.rawValue)
                .font(.headline)
            
            Text("\(Int(progress * 100))%")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .animation(.default, value: progress)
            
            if phase == .downloading {
                Text("请稍候，正在从服务器下载...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

/// 搜索内容视图
struct CardSearchContentView: View {
    @ObservedObject var viewModel: CardSearchViewModel
    @ObservedObject var filter: CardFilter
    @Binding var showFilter: Bool
    
    /// 每页显示数量
    private let pageSize = 100
    @State private var displayCount = 100
    @State private var listId = UUID()
    
    /// 基础数据源（搜索结果或全部卡片）
    var baseCards: [Card] {
        if viewModel.searchText.isEmpty {
            // 无搜索词时，只有在有筛选条件时才返回全部卡片
            if filter.hasActiveFilters {
                return CardRepository.shared.getAllCards()
            } else {
                return []  // 无搜索词且无筛选条件时返回空数组
            }
        } else {
            return viewModel.searchResults
        }
    }
    
    /// 应用筛选后的结果
    var filteredResults: [Card] {
        filter.apply(to: baseCards)
    }
    
    /// 当前显示的卡片（分页）
    var displayedCards: [Card] {
        Array(filteredResults.prefix(displayCount))
    }
    
    /// 是否还有更多卡片
    var hasMore: Bool {
        displayCount < filteredResults.count
    }

    private let monsterCategoryTags: [(String, CardType)] = [
        ("通常", .normal),
        ("效果", .effect),
        ("融合", .fusion),
        ("仪式", .ritual),
        ("同调", .synchro),
        ("超量", .xyz),
        ("链接", .link)
    ]

    private let monsterAbilityTags: [(String, CardType)] = [
        ("灵摆", .pendulum),
        ("调整", .tuner),
        ("反转", .flip),
        ("卡通", .toon),
        ("灵魂", .spirit),
        ("同盟", .union),
        ("二重", .dual)
    ]

    private let spellTypeTags: [(String, CardType)] = [
        ("通常魔法", CardType(rawValue: 0)),
        ("速攻魔法", .quickPlay),
        ("永续魔法", .continuous),
        ("装备魔法", .equip),
        ("场地魔法", .field),
        ("仪式魔法", .ritual)
    ]

    private let trapTypeTags: [(String, CardType)] = [
        ("通常陷阱", CardType(rawValue: 0)),
        ("永续陷阱", .continuous),
        ("反击陷阱", .counter)
    ]

    private var activeFilterTags: [String] {
        var tags: [String] = []

        for (name, type) in monsterCategoryTags where filter.selectedMonsterCategories.contains(type) {
            tags.append(name)
        }
        for (name, type) in monsterAbilityTags where filter.selectedMonsterAbilities.contains(type) {
            tags.append(name)
        }
        for level in filter.selectedLevels.sorted() {
            tags.append("\(CardFilter.levelDisplayTitle(for: level))星")
        }
        for race in filter.selectedRaces.sorted(by: { $0.rawValue < $1.rawValue }) {
            tags.append(race.displayName)
        }
        for attr in filter.selectedAttributes.sorted(by: { $0.rawValue < $1.rawValue }) {
            tags.append(attr.displayName)
        }
        for (name, type) in spellTypeTags where filter.selectedSpellTypes.contains(type) {
            tags.append(name)
        }
        for (name, type) in trapTypeTags where filter.selectedTrapTypes.contains(type) {
            tags.append(name)
        }

        return tags
    }

    private var previewFilterTags: [String] {
        Array(activeFilterTags.prefix(8))
    }
    
    var body: some View {
        // 预先计算筛选结果，避免在视图中多次重复计算
        let results = filteredResults
        let cards = Array(results.prefix(displayCount))
        let showMore = displayCount < results.count
        let isEmpty = results.isEmpty
        let totalCount = results.count
        
        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("搜索卡片...", text: $viewModel.searchText)
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit {
                                guard !viewModel.searchText.isEmpty else { return }
                                AppSettings.shared.addSearchHistory(viewModel.searchText)
                            }

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        showFilter = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        .frame(width: 36, height: 36)
                        .background(filter.hasActiveFilters ? Color.blue.opacity(0.14) : Color.gray.opacity(0.12))
                        .foregroundColor(filter.hasActiveFilters ? .blue : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if filter.hasActiveFilters {
                    HStack(spacing: 8) {
                        Text("已选 \(activeFilterTags.count) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.reset()
                            }
                        } label: {
                            Text("清空")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                }

                if filter.hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(previewFilterTags.enumerated()), id: \.offset) { _, tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.10))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }

                            if activeFilterTags.count > previewFilterTags.count {
                                Text("+\(activeFilterTags.count - previewFilterTags.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, filter.hasActiveFilters ? 8 : 6)
            .background(Color(UIColor.systemBackground))
            .overlay(alignment: .bottom) {
                Divider()
            }
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.2), value: filter.hasActiveFilters)

            List {
                if isEmpty {
                    // 空状态提示
                    EmptyStateRow(
                        searchText: viewModel.searchText,
                        hasActiveFilters: filter.hasActiveFilters
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                } else {
                    // 卡片列表
                    ForEach(cards) { card in
                        NavigationLink(destination: CardDetailView(card: card)) {
                            CardRowView(card: card)
                        }
                        .contextMenu {
                            Button {
                                copyCardInfo(card)
                            } label: {
                                Label("复制卡片信息", systemImage: "doc.on.doc")
                            }
                        }
                    }

                    // 加载更多按钮
                    if showMore {
                        Button {
                            displayCount += pageSize
                        } label: {
                            Text("加载更多 (\(totalCount - displayCount) 张)")
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowSeparator(.hidden)
                    }

                    // 底部统计
                    Text("共 \(totalCount) 张卡片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .id(listId)
            .animation(.easeInOut(duration: 0.2), value: isEmpty)
            .overlay(alignment: .center) {
                // 加载指示器
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .allowsHitTesting(false)
                }
            }
        }
        .onChange(of: viewModel.searchText) { newValue in
            // 搜索词变化时重置分页（带动画）
            withAnimation(.easeInOut(duration: 0.2)) {
                displayCount = pageSize
            }
            // 取消搜索时刷新列表 id，强制回到顶部
            if newValue.isEmpty {
                listId = UUID()
            }
        }
        .onChange(of: filter.selectedCategory) { _ in
            // 类别变化时重置分页
            withAnimation(.easeInOut(duration: 0.2)) {
                displayCount = pageSize
            }
        }
        .onChange(of: filter.hasActiveFilters) { _ in
            // 筛选条件变化时重置分页
            withAnimation(.easeInOut(duration: 0.2)) {
                displayCount = pageSize
            }
        }
    }
    
    /// 复制卡片信息到剪贴板
    private func copyCardInfo(_ card: Card) {
        let settings = AppSettings.shared
        let displayName = settings.getDisplayName(for: card)
        var info = "【\(displayName)】\n"
        info += "\(card.typesDisplay)\n\n"
        
        if !card.pdescDisplay.isEmpty {
            info += "【灵摆效果】\n\(card.pdescDisplay)\n\n"
        }
        
        info += "【效果】\n\(card.descDisplay)"
        
        UIPasteboard.general.string = info
    }
}

/// iOS 15 兼容的空状态视图
struct EmptySearchResultView: View {
    let message: String
    let hint: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(hint)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 用于 List 内部的空状态行（解决 iOS 15 搜索栏问题）
struct EmptyStateRow: View {
    let searchText: String
    let hasActiveFilters: Bool
    
    var message: String {
        if !searchText.isEmpty {
            return "未找到卡片"
        } else if hasActiveFilters {
            return "无符合条件的卡片"
        } else {
            return "搜索或浏览卡片"
        }
    }
    
    var hint: String {
        if !searchText.isEmpty {
            return "尝试使用其他关键词搜索\n或调整筛选条件"
        } else if hasActiveFilters {
            return "尝试调整筛选条件"
        } else {
            return "输入关键词搜索\n或点击筛选按钮浏览全部卡片"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(hint)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
        .padding(.vertical, 40)
    }
}

#Preview {
    SearchView()
}
