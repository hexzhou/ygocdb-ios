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
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadedKey: String = ""
    
    init(
        url: URL?,
        cacheKey: String = "",
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey.isEmpty ? (url?.absoluteString ?? "") : cacheKey
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
                loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() {
        guard let url = url else { return }
        
        let key = currentKey
        
        // 如果已经加载了相同的 key，不需要重新加载
        if loadedKey == key && image != nil {
            return
        }
        
        // 如果正在加载相同的 key，不需要重复加载
        if isLoading && loadedKey == key {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let loadedImage = try await ImageCache.shared.downloadAndCache(from: url)
                await MainActor.run {
                    // 确保 key 没有在加载过程中改变
                    if currentKey == key {
                        self.image = loadedImage
                        self.loadedKey = key
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

/// 简化版本，使用默认占位符
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        url: URL?,
        cacheKey: String = "",
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, cacheKey: cacheKey, content: content) {
            ProgressView()
        }
    }
}
