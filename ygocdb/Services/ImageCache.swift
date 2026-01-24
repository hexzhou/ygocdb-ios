//
//  ImageCache.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import SwiftUI
import os.log

/// 图片缓存管理器
actor ImageCache {
    static let shared = ImageCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, UIImage>()
    private let logger = Logger(subsystem: "com.ygocdb", category: "ImageCache")
    private let session: URLSession

    /// 并发下载任务管理器（限制同时下载数量）
    private var ongoingDownloads: [URL: Task<UIImage, Error>] = [:]
    private let maxConcurrentDownloads = 6
    private var activeDownloadCount = 0

    private init() {
        // 使用共享的网络配置
        self.session = NetworkConfig.shared

        // 获取缓存目录
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("CardImages", isDirectory: true)

        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 设置内存缓存限制
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    /// 从 URL 解析出语言、卡片ID和尺寸，生成可读的缓存文件名
    /// 例如: https://cdn.233.momobako.com/ygopro/pics/89631139.jpg!thumb2 -> ygopro_89631139_thumb2.jpg
    private func cacheFileName(for url: URL) -> String {
        let urlString = url.absoluteString
        
        // 解析语言/路径
        var language = "unknown"
        if urlString.contains("/ygopro/pics/") {
            language = "ygopro"
        } else if urlString.contains("/ygoimg/sc/") {
            language = "sc"
        } else if urlString.contains("/ygoimg/jp/") {
            language = "jp"
        } else if urlString.contains("/ygoimg/en/") {
            language = "en"
        }
        
        // 从 URL 路径中提取卡片 ID（使用正则或字符串处理）
        // URL 格式示例：
        // - https://cdn.233.momobako.com/ygopro/pics/89631139.jpg!thumb2
        // - https://cdn.233.momobako.com/ygoimg/sc/89392810.webp!/format/webp/fw/400/quality/85
        var cardId = "0"
        var ext = "jpg"
        
        // 使用正则表达式提取卡片ID：匹配数字.扩展名
        if let range = urlString.range(of: #"/(\d+)\.(jpg|webp|png)"#, options: .regularExpression) {
            let match = String(urlString[range])
            // 去掉开头的 / 
            let filename = String(match.dropFirst())
            if let dotIndex = filename.firstIndex(of: ".") {
                cardId = String(filename[..<dotIndex])
                ext = String(filename[filename.index(after: dotIndex)...])
            }
        }
        
        // 解析尺寸
        var size = "full"
        if urlString.contains("!/format/webp") || urlString.contains("/fw/") {
            // 高清 WebP 格式
            size = "hd_webp"
            ext = "webp"
        } else if urlString.hasSuffix("!half") {
            size = "half"
        } else if urlString.hasSuffix("!thumb2") {
            size = "thumb2"
        } else if urlString.hasSuffix("!thumb") {
            size = "thumb"
        } else if urlString.hasSuffix("!art") {
            size = "art"
        }
        
        // 生成可读的缓存文件名: ygopro_89631139_thumb2.jpg
        return "\(language)_\(cardId)_\(size).\(ext)"
    }
    
    /// 获取缓存文件路径
    private func cacheFileURL(for url: URL) -> URL {
        cacheDirectory.appendingPathComponent(cacheFileName(for: url))
    }
    
    /// 从缓存加载图片
    func loadImage(for url: URL) async -> UIImage? {
        let cacheKey = cacheFileName(for: url) as NSString
        
        // 1. 检查内存缓存
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // 2. 检查磁盘缓存
        let fileURL = cacheFileURL(for: url)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // 存入内存缓存
            memoryCache.setObject(image, forKey: cacheKey, cost: data.count)
            return image
        }
        
        return nil
    }
    
    /// 下载并缓存图片（带并发控制）
    func downloadAndCache(from url: URL) async throws -> UIImage {
        let cacheKey = cacheFileName(for: url) as NSString

        // 先检查内存缓存
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // 检查磁盘缓存
        let fileURL = cacheFileURL(for: url)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey, cost: data.count)
            return image
        }

        // 检查是否已有正在进行的下载任务
        if let existingTask = ongoingDownloads[url] {
            return try await existingTask.value
        }

        // 创建新的下载任务
        let downloadTask = Task<UIImage, Error> {
            // 等待直到有可用的下载槽位
            while activeDownloadCount >= maxConcurrentDownloads {
                try await Task.sleep(nanoseconds: 50_000_000) // 等待50ms
            }

            activeDownloadCount += 1

            // 确保无论成功还是失败都清理资源
            defer {
                Task {
                    await self.cleanupDownload(url: url)
                }
            }

            do {
                // 下载图片
                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("❌ 下载失败: \(cacheKey as String) - 无效响应")
                    throw ImageCacheError.downloadFailed
                }

                guard httpResponse.statusCode == 200 else {
                    logger.error("❌ 下载失败: \(cacheKey as String) - HTTP \(httpResponse.statusCode)")
                    throw ImageCacheError.downloadFailed
                }

                guard let image = UIImage(data: data) else {
                    logger.error("❌ 下载失败: \(cacheKey as String) - 图片解码失败")
                    throw ImageCacheError.downloadFailed
                }

                // 保存到磁盘
                try? data.write(to: fileURL)

                // 存入内存缓存
                memoryCache.setObject(image, forKey: cacheKey, cost: data.count)

                return image
            } catch {
                logger.error("❌ 下载异常: \(cacheKey as String) - \(error.localizedDescription)")
                throw error
            }
        }

        ongoingDownloads[url] = downloadTask
        return try await downloadTask.value
    }

    /// 清理下载任务（私有辅助方法）
    private func cleanupDownload(url: URL) {
        activeDownloadCount -= 1
        ongoingDownloads.removeValue(forKey: url)
    }
    
    /// 清除所有缓存
    func clearCache() async {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        logger.info("✅ 缓存已清除")
    }
    
    /// 获取缓存大小（字节）
    func cacheSize() async -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        return size
    }
    
    /// 格式化缓存大小
    func formattedCacheSize() async -> String {
        let size = await cacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// 图片缓存错误
enum ImageCacheError: Error, LocalizedError {
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "图片下载失败"
        }
    }
}
