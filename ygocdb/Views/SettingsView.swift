//
//  SettingsView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

/// 设置视图
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var imageCacheSize: String = "计算中..."
    @State private var cardDataSize: String = "计算中..."
    @State private var showClearImageCacheAlert = false
    @State private var showClearCardDataAlert = false
    @State private var isCheckingForUpdates = false
    @State private var updateCheckResult: String?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var showUpdateConfirmAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // 网络设置
                Section {
                    Picker("网络模式", selection: $settings.networkMode) {
                        ForEach(NetworkMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if settings.networkMode == .online {
                        Picker("更新模式", selection: $settings.updateMode) {
                            ForEach(UpdateMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        if settings.updateMode == .automatic {
                            Picker("更新策略", selection: $settings.autoUpdatePolicy) {
                                ForEach(AutoUpdatePolicy.allCases, id: \.self) { policy in
                                    Text(policy.rawValue).tag(policy)
                                }
                            }
                        }
                    }
                    
                    // 检查更新按钮
                    Button {
                        Task { await checkForUpdates() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("检查更新")
                            Spacer()
                            if isCheckingForUpdates {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let result = updateCheckResult {
                                Text(result)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .disabled(isCheckingForUpdates || isDownloading)
                    .tint(.green)
                    
                    // 下载进度
                    if isDownloading {
                        VStack(spacing: 8) {
                            HStack {
                                Text("正在下载更新...")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(downloadProgress * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            ProgressView(value: downloadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                        .animation(.default, value: downloadProgress)
                    }
                } header: {
                    Text("更新设置")
                } footer: {
                    if settings.networkMode == .offline {
                        Text("离线模式下仅支持手动更新，不会自动检查更新")
                    } else if settings.updateMode == .automatic {
                        Text("自动更新：进入应用时根据策略自动检查更新")
                    } else {
                        Text("手动更新：需要手动点击检查更新按钮")
                    }
                }
                
                // 译名翻译
                Section {
                    Picker("译名来源", selection: $settings.cardNameSource) {
                        ForEach(CardNameSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                } header: {
                    Text("译名翻译")
                } footer: {
                    Text("选择卡片名称的翻译来源")
                }
                
                // 卡图语言
                Section {
                    Picker("卡图语言", selection: $settings.cardImageLanguage) {
                        ForEach(CardImageLanguage.allCases, id: \.self) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                } header: {
                    Text("卡图语言")
                } footer: {
                    Text("选择显示的卡图语言版本")
                }
                
                // 卡图清晰度
                Section {
                    Picker("详情页卡图", selection: $settings.detailImageQuality) {
                        ForEach(DetailImageQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("卡图清晰度")
                } footer: {
                    Text("原图为完整尺寸，高清为中等尺寸，缩略图加载更快")
                }
                
                // 列表样式
                Section {
                    Picker("列表样式", selection: $settings.cardListStyle) {
                        ForEach(CardListStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("显示样式")
                } footer: {
                    Text("简洁模式显示缩略图和摘要，详细模式显示完整效果")
                }
                
                // 缓存管理
                Section {
                    // 图片缓存
                    HStack {
                        Text("图片缓存")
                        Spacer()
                        Text(imageCacheSize)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        showClearImageCacheAlert = true
                    } label: {
                        Text("清除图片缓存")
                    }
                    
                    // 卡片数据
                    HStack {
                        Text("卡片数据")
                        Spacer()
                        Text(cardDataSize)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        showClearCardDataAlert = true
                    } label: {
                        Text("清除卡片数据")
                    }
                } header: {
                    Text("数据管理")
                } footer: {
                    Text("清除卡片数据后需要重新下载")
                }
                
                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("数据来源")
                        Spacer()
                        Link("ygocdb.com", destination: URL(string: "https://ygocdb.com")!)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("个人网站")
                        Spacer()
                        Link("ihex.dev", destination: URL(string: "https://ihex.dev")!)
                            .foregroundColor(.blue)
                    }
                    
                    if let lastCheck = settings.lastUpdateCheckTime {
                        HStack {
                            Text("上次检查更新")
                            Spacer()
                            Text(lastCheck, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await updateSizes()
            }
            .alert("清除图片缓存", isPresented: $showClearImageCacheAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    Task {
                        await ImageCache.shared.clearCache()
                        await updateSizes()
                    }
                }
            } message: {
                Text("确定要清除所有缓存的卡图吗？")
            }
            .alert("清除卡片数据", isPresented: $showClearCardDataAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    CardRepository.shared.clearCardData()
                    updateCardDataSize()
                    dismiss()
                }
            } message: {
                Text("确定要清除所有卡片数据吗？\n清除后需要重新下载才能使用。")
            }
            .alert("发现新版本", isPresented: $showUpdateConfirmAlert) {
                Button("稍后再说", role: .cancel) {}
                Button("立即更新") {
                    Task { await downloadUpdate() }
                }
            } message: {
                Text("卡片数据库有新版本可用，是否立即下载更新？")
            }
        }
    }
    
    private func updateSizes() async {
        imageCacheSize = await ImageCache.shared.formattedCacheSize()
        updateCardDataSize()
    }
    
    private func updateCardDataSize() {
        cardDataSize = CardRepository.shared.formattedDataSize()
    }
    
    private func checkForUpdates() async {
        isCheckingForUpdates = true
        updateCheckResult = nil
        
        do {
            let localMD5 = CardRepository.shared.getLocalMD5()
            let newMD5 = try await YGODBService.shared.checkForNewResource(localMD5: localMD5)
            
            // 更新检查时间
            AppSettings.shared.lastUpdateCheckTime = Date()
            
            if newMD5 != nil {
                updateCheckResult = "发现新版本"
                showUpdateConfirmAlert = true
            } else {
                updateCheckResult = "已是最新版本"
            }
        } catch {
            updateCheckResult = "检查失败"
        }
        
        isCheckingForUpdates = false
    }
    
    private func downloadUpdate() async {
        isDownloading = true
        downloadProgress = 0.0
        updateCheckResult = nil
        
        do {
            let md5 = try await YGODBService.shared.fetchMD5()
            
            let cardDatabase = try await YGODBService.shared.downloadCards { progress in
                Task { @MainActor in
                    self.downloadProgress = progress
                }
            }
            
            try await CardRepository.shared.saveCards(cardDatabase, md5: md5)
            
            updateCheckResult = "更新完成"
            updateCardDataSize()
        } catch {
            updateCheckResult = "下载失败"
        }
        
        isDownloading = false
    }
}

#Preview {
    SettingsView()
}
