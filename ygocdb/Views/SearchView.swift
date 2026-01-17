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
            .navigationBarTitleDisplayMode(.large)
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
                        
                        // 竖向分割线
                        Divider()
                            .frame(height: 20)
                        
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
    
    var body: some View {
        // 预先计算筛选结果，避免在视图中多次重复计算
        let results = filteredResults
        let cards = Array(results.prefix(displayCount))
        let showMore = displayCount < results.count
        let isEmpty = results.isEmpty
        let totalCount = results.count
        
        return List {
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
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索卡片...") {
            // 搜索历史建议（仅在搜索框为空时显示）
            if viewModel.searchText.isEmpty {
                let history = AppSettings.shared.searchHistory
                if !history.isEmpty {
                    Section {
                        ForEach(history, id: \.self) { item in
                            Button {
                                // 点击历史记录：填充搜索词、保存历史、收起键盘
                                viewModel.searchText = item
                                AppSettings.shared.addSearchHistory(item)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                HStack {
                                    Label(item, systemImage: "clock.arrow.circlepath")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    AppSettings.shared.removeSearchHistory(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                        
                        Button(role: .destructive) {
                            AppSettings.shared.clearSearchHistory()
                        } label: {
                            Label("清空历史记录", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("搜索历史")
                    }
                }
            }
        }
        .onSubmit(of: .search) {
            // 搜索提交时保存历史记录
            AppSettings.shared.addSearchHistory(viewModel.searchText)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
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
