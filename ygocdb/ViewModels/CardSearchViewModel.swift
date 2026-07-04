//
//  CardSearchViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import Combine
import os.log

/// 下载阶段枚举
enum DownloadPhase: String {
    case idle = "待机"
    case fetchingMD5 = "获取版本信息..."
    case downloading = "下载卡片数据..."
    case extracting = "解压数据..."
    case parsing = "解析卡片信息..."
    case saving = "保存到本地..."
    case completed = "完成"
}

/// 卡片搜索视图模型
@MainActor
class CardSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [Card] = []
    @Published var isSearching: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadPhase: DownloadPhase = .idle
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // 更新检查相关
    @Published var showUpdateAvailableAlert: Bool = false
    @Published var isCheckingForUpdates: Bool = false
    @Published var updateCheckResult: String?
    
    // 监听 Repository 的状态变化
    @Published private(set) var hasLocalData: Bool = false
    @Published private(set) var isDataLoaded: Bool = false
    
    private var repository: CardRepository
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.ygocdb", category: "ViewModel")
    
    init() {
        self.repository = CardRepository.shared
        
        // 初始化状态
        self.hasLocalData = repository.hasLocalData
        self.isDataLoaded = repository.isLoaded
        
        setupSearchDebounce()
        setupRepositoryObserver()
    }
    
    /// 设置搜索防抖
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    /// 监听 Repository 状态变化
    private func setupRepositoryObserver() {
        repository.$isLoaded
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoaded in
                self?.isDataLoaded = isLoaded
                self?.hasLocalData = self?.repository.hasLocalData ?? false
            }
            .store(in: &cancellables)
            
        repository.$cards
            .receive(on: RunLoop.main)
            .removeDuplicates { $0.count == $1.count }
            .sink { [weak self] cards in
                // 当卡片数据变化时，如果当前有搜索，重新执行搜索
                if let self = self, !self.searchText.isEmpty {
                    self.performSearch(query: self.searchText)
                }
            }
            .store(in: &cancellables)
    }
    
    /// 执行搜索（优化版本：后台线程搜索）
    private func performSearch(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            // 延迟清空搜索结果，减少取消搜索时的残影
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                if searchText.isEmpty {
                    searchResults = []
                }
                isSearching = false
            }
            return
        }

        isSearching = true

        searchTask = Task {
            // 异步后台搜索，不阻塞主线程
            let results = await repository.search(query)

            // 无论是否取消，都需要重置 isSearching 状态
            if Task.isCancelled {
                await MainActor.run { isSearching = false }
                return
            }

            searchResults = results
            isSearching = false
        }
    }
    
    /// 加载本地卡片数据
    func loadLocalData() async {
        do {
            try await repository.loadCards()
            hasLocalData = repository.hasLocalData
            isDataLoaded = repository.isLoaded
        } catch {
            if error.isTaskCancellation || Task.isCancelled {
                return
            }

            errorMessage = "加载本地数据失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    /// 下载全卡数据
    func downloadAllCards() async {
        isDownloading = true
        downloadProgress = 0.0
        downloadPhase = .fetchingMD5
        downloadedBytes = 0
        totalBytes = 0
        errorMessage = nil
        
        logger.info("🚀 开始下载流程")
        
        do {
            // 先获取 MD5
            logger.info("📥 获取 MD5...")
            let md5 = try await YGODBService.shared.fetchMD5()
            logger.info("✅ MD5: \(md5)")
            
            // 下载卡片数据
            downloadPhase = .downloading
            logger.info("📥 开始下载卡片数据...")
            
            let cardDatabase = try await YGODBService.shared.downloadCards { [weak self] progress in
                self?.downloadProgress = progress
            }
            
            logger.info("✅ 下载完成，共 \(cardDatabase.count) 张卡片")
            
            // 保存到本地
            downloadPhase = .saving
            logger.info("💾 保存到本地...")
            try await repository.saveCards(cardDatabase, md5: md5)
            
            downloadPhase = .completed
            isDownloading = false
            downloadProgress = 1.0
            hasLocalData = repository.hasLocalData
            isDataLoaded = repository.isLoaded
            logger.info("🎉 全部完成!")
            
        } catch {
            if error.isTaskCancellation || Task.isCancelled {
                isDownloading = false
                downloadPhase = .idle
                return
            }

            isDownloading = false
            downloadPhase = .idle
            let errorDesc = error.localizedDescription
            errorMessage = "下载失败: \(errorDesc)"
            showError = true
            logger.error("❌ 下载失败: \(errorDesc)")
        }
    }
    
    /// 根据设置执行自动更新检查（仅在应用启动时调用）
    func performAutoUpdateCheckIfNeeded() async {
        // 检查是否应该自动检查更新
        guard AppSettings.shared.shouldCheckForUpdates() else {
//            logger.info("📴 跳过自动更新检查（离线模式/手动模式/未到检查时间）")
            return
        }
        
        logger.info("🔄 开始自动更新检查...")
        await checkForUpdates(silent: true)
    }
    
    /// 手动检查更新
    func checkForUpdates(silent: Bool = false) async {
        isCheckingForUpdates = true
        updateCheckResult = nil
        
        do {
            let localMD5 = repository.getLocalMD5()
            let newMD5 = try await YGODBService.shared.checkForNewResource(localMD5: localMD5)
            
            // 更新检查时间
            AppSettings.shared.lastUpdateCheckTime = Date()
            
            if newMD5 != nil {
                logger.info("🆕 发现新版本")
                showUpdateAvailableAlert = true
                updateCheckResult = "发现新版本"
            } else {
                logger.info("✅ 已是最新版本")
                if !silent {
                    updateCheckResult = "已是最新版本"
                }
            }
        } catch {
            logger.error("❌ 检查更新失败: \(error.localizedDescription)")
            if !silent {
                updateCheckResult = "检查失败"
            }
        }
        
        isCheckingForUpdates = false
    }
    
    /// 刷新状态（清除数据后调用）
    func refreshState() {
        hasLocalData = repository.hasLocalData
        isDataLoaded = repository.isLoaded
        searchResults = []
        searchText = ""
    }
}
