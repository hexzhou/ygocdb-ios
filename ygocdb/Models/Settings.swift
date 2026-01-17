//
//  Settings.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import SwiftUI
import Combine

/// 网络模式
enum NetworkMode: String, CaseIterable, Codable {
    case online = "在线"
    case offline = "离线"
}

/// 更新模式
enum UpdateMode: String, CaseIterable, Codable {
    case automatic = "自动更新"
    case manual = "手动更新"
}

/// 自动更新策略
enum AutoUpdatePolicy: String, CaseIterable, Codable {
    case everyHour = "每隔1小时"
    case every24Hours = "每隔24小时"
    case every7Days = "每隔7天"
    
    /// 获取策略对应的时间间隔（秒）
    var interval: TimeInterval {
        switch self {
        case .everyHour:
            return 60 * 60
        case .every24Hours:
            return 24 * 60 * 60
        case .every7Days:
            return 7 * 24 * 60 * 60
        }
    }
}

/// 译名翻译来源
enum CardNameSource: String, CaseIterable, Codable {
    case ygopro = "YGOPRO"
    case sc = "简体中文"
    case masterDuel = "Master Duel"
    case nwbbs = "NWBBS"
    case cnocg = "CNOCG"
    
    /// 获取卡片对应的名称
    func getName(from card: Card) -> String {
        switch self {
        case .ygopro:
            return card.cnName ?? card.scName ?? card.jpName ?? "未知卡片"
        case .sc:
            return card.scName ?? card.cnName ?? card.jpName ?? "未知卡片"
        case .masterDuel:
            return card.mdName ?? card.scName ?? card.cnName ?? "未知卡片"
        case .nwbbs:
            return card.nwbbsN ?? card.cnName ?? card.jpName ?? "未知卡片"
        case .cnocg:
            return card.cnocgN ?? card.cnName ?? card.jpName ?? "未知卡片"
        }
    }
}

/// 卡图语言
enum CardImageLanguage: String, CaseIterable, Codable {
    case ygopro = "YGOPRO"
    case sc = "简体中文"
    case jp = "日文"
    case en = "英文"
    
    /// 获取卡图 CDN 路径
    var cdnPath: String {
        switch self {
        case .ygopro:
            return "ygopro/pics"
        case .sc:
            return "ygoimg/sc"
        case .jp:
            return "ygoimg/jp"
        case .en:
            return "ygoimg/en"
        }
    }
    
    /// 获取图片扩展名
    var imageExtension: String {
        switch self {
        case .ygopro:
            return "jpg"
        case .sc, .jp, .en:
            return "webp"
        }
    }
    
    /// 获取卡图 URL
    func getImageURL(for cardId: Int, size: CardImageSize = .full) -> URL? {
        let baseURL = "https://cdn.233.momobako.com"
        let sizeSuffix = size.suffix
        return URL(string: "\(baseURL)/\(cdnPath)/\(cardId).\(imageExtension)\(sizeSuffix)")
    }
}

/// 卡图尺寸
enum CardImageSize {
    case full       // 完整尺寸
    case half       // 高清 WebP (宽400, 质量85)
    case thumb2     // 82x120
    case thumb      // 44x64
    
    var suffix: String {
        switch self {
        case .full:
            return ""
        case .half:
            return "!/format/webp/fw/400/quality/85"
        case .thumb2:
            return "!thumb2"
        case .thumb:
            return "!thumb"
        }
    }
}

/// 列表样式
enum CardListStyle: String, CaseIterable, Codable {
    case compact = "简洁"
    case detailed = "详细"
}

/// 详情页卡图清晰度
enum DetailImageQuality: String, CaseIterable, Codable {
    case original = "原图"
    case high = "高清"
    case thumbnail = "缩略图"
    
    var size: CardImageSize {
        switch self {
        case .original: return .full
        case .high: return .half
        case .thumbnail: return .thumb2
        }
    }
}

/// 应用设置管理器
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @AppStorage("cardNameSource") var cardNameSource: CardNameSource = .ygopro
    @AppStorage("cardImageLanguage") var cardImageLanguage: CardImageLanguage = .ygopro
    @AppStorage("cardListStyle") var cardListStyle: CardListStyle = .compact
    @AppStorage("detailImageQuality") var detailImageQuality: DetailImageQuality = .high
    
    // 网络和更新设置
    @AppStorage("networkMode") var networkMode: NetworkMode = .online
    @AppStorage("updateMode") var updateMode: UpdateMode = .automatic
    @AppStorage("autoUpdatePolicy") var autoUpdatePolicy: AutoUpdatePolicy = .everyHour
    @AppStorage("lastUpdateCheckTime") private var lastUpdateCheckTimeInterval: Double = 0
    
    /// 上次检查更新时间
    var lastUpdateCheckTime: Date? {
        get {
            lastUpdateCheckTimeInterval == 0 ? nil : Date(timeIntervalSince1970: lastUpdateCheckTimeInterval)
        }
        set {
            lastUpdateCheckTimeInterval = newValue?.timeIntervalSince1970 ?? 0
        }
    }
    
    /// 根据更新策略判断是否需要检查更新
    func shouldCheckForUpdates() -> Bool {
        // 离线模式不自动检查
        guard networkMode == .online else { return false }
        // 手动更新模式不自动检查
        guard updateMode == .automatic else { return false }
        
        guard let lastCheck = lastUpdateCheckTime else {
            return true // 从未检查过
        }
        
        return Date().timeIntervalSince(lastCheck) > autoUpdatePolicy.interval
    }
    
    private init() {}
    
    /// 获取卡片显示名称
    func getDisplayName(for card: Card) -> String {
        cardNameSource.getName(from: card)
    }
    
    /// 获取卡图 URL
    func getImageURL(for card: Card, size: CardImageSize = .full) -> URL? {
        cardImageLanguage.getImageURL(for: card.id, size: size)
    }
    
    // MARK: - 搜索历史
    
    /// 最大搜索历史记录数
    private let maxSearchHistoryCount = 5
    
    /// 搜索历史 key
    private let searchHistoryKey = "searchHistory"
    
    /// 获取搜索历史
    var searchHistory: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: searchHistoryKey) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: searchHistoryKey)
            objectWillChange.send()
        }
    }
    
    /// 添加搜索记录
    func addSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        var history = searchHistory
        // 移除已存在的相同记录
        history.removeAll { $0 == trimmed }
        // 添加到开头
        history.insert(trimmed, at: 0)
        // 保留最近5条
        if history.count > maxSearchHistoryCount {
            history = Array(history.prefix(maxSearchHistoryCount))
        }
        searchHistory = history
    }
    
    /// 删除单条搜索记录
    func removeSearchHistory(_ query: String) {
        var history = searchHistory
        history.removeAll { $0 == query }
        searchHistory = history
    }
    
    /// 清空搜索历史
    func clearSearchHistory() {
        searchHistory = []
    }
}
