//
//  CachedAsyncImage.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

/// 带缓存的异步图片视图
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let cacheKey: String  // 添加缓存 key 用于强制刷新
    let maxRetries: Int  // 最大重试次数
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadedKey: String = ""
    @State private var failedToLoad = false  // 标记是否加载失败

    init(
        url: URL?,
        cacheKey: String = "",
        maxRetries: Int = 2,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey.isEmpty ? (url?.absoluteString ?? "") : cacheKey
        self.maxRetries = maxRetries
        self.content = content
        self.placeholder = placeholder
    }
    
    /// 当前的完整 key（URL + cacheKey）
    private var currentKey: String {
        "\(url?.absoluteString ?? "")-\(cacheKey)"
    }
    
    var body: some View {
        Group {
            if let image = image, loadedKey == currentKey {
                content(Image(uiImage: image))
            } else if failedToLoad {
                // 加载失败后显示默认占位图
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无卡图")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: currentKey) { _ in
            // Key 变化时重新加载
            if loadedKey != currentKey {
                image = nil
                failedToLoad = false
                loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() {
        guard let url = url else {
            failedToLoad = true
            return
        }

        let key = currentKey

        // 如果已经加载了相同的 key，不需要重新加载
        if loadedKey == key && image != nil {
            return
        }

        // 如果正在加载相同的 key，不需要重复加载
        if isLoading && loadedKey == key {
            return
        }

        // 【优化】先同步检查内存缓存，避免不必要的 loading 状态
        Task {
            // 优先从内存缓存快速加载（同步操作，无需显示 loading）
            if let cachedImage = await ImageCache.shared.loadImage(for: url) {
                await MainActor.run {
                    if currentKey == key {
                        self.image = cachedImage
                        self.loadedKey = key
                        self.failedToLoad = false
                    }
                }
                return  // 缓存命中，直接返回
            }

            // 缓存未命中，开始显示 loading 并下载
            await MainActor.run {
                self.isLoading = true
                self.failedToLoad = false
            }

            var lastError: Error?

            // 重试机制
            for attempt in 0...maxRetries {
                do {
                    let loadedImage = try await ImageCache.shared.downloadAndCache(from: url)
                    await MainActor.run {
                        // 确保 key 没有在加载过程中改变
                        if currentKey == key {
                            self.image = loadedImage
                            self.loadedKey = key
                            self.failedToLoad = false
                        }
                        self.isLoading = false
                    }
                    return  // 成功加载，退出
                } catch {
                    lastError = error
                    if attempt < maxRetries {
                        // 等待后重试（指数退避：100ms, 200ms）
                        try? await Task.sleep(nanoseconds: UInt64(100_000_000 * (1 << attempt)))
                    }
                }
            }

            // 所有重试都失败
            await MainActor.run {
                self.isLoading = false
                self.failedToLoad = true
            }
        }
    }
}

/// 简化版本，使用默认占位符
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        url: URL?,
        cacheKey: String = "",
        maxRetries: Int = 2,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, cacheKey: cacheKey, maxRetries: maxRetries, content: content) {
            ProgressView()
        }
    }
}
