//
//  NetworkConfig.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/13.
//

import Foundation

/// 网络配置
enum NetworkConfig {
    /// 应用版本
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Bundle ID
    static var bundleId: String {
        Bundle.main.bundleIdentifier ?? "dev.ihex.ygocdb"
    }
    
    /// User-Agent
    static var userAgent: String {
        "ygocdb/\(appVersion) (iOS; \(bundleId))"
    }
    
    /// 共享的 URLSession（默认超时 60s）
    static let shared: URLSession = {
        makeSession(timeout: 60)
    }()
    
    /// 长时间任务的 URLSession（用于下载大文件，超时 300s）
    static let longTask: URLSession = {
        makeSession(timeout: 300)
    }()
    
    /// 创建配置了 User-Agent 的 URLSession
    static func makeSession(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 5
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent
        ]
        return URLSession(configuration: config)
    }
}
