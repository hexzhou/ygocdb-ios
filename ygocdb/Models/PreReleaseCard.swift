//
//  PreReleaseCard.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/13.
//

import Foundation

/// 先行卡数据模型
struct PreReleaseCard: Codable, Identifiable {
    let id: Int
    let name: String
    let desc: String
    let overallString: String
    let picUrl: String
    let createTime: Int
    let updateTime: Int
    let created: Bool
    let updated: Bool
    
    // 可选字段
    let createCommit: String?
    let updateCommit: String?
    
    /// 是否是新卡（新增或更新）
    var isNew: Bool {
        created || updated
    }
    
    /// 状态标签
    var statusLabel: String? {
        if created {
            return "NEW"
        } else if updated {
            return "更新"
        }
        return nil
    }
    
    /// 创建时间格式化
    var createDateString: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 更新时间格式化
    var updateDateString: String {
        let date = Date(timeIntervalSince1970: TimeInterval(updateTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    /// 卡图 URL
    var imageURL: URL? {
        URL(string: picUrl)
    }
}
