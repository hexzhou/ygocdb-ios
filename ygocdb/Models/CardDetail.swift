//
//  CardDetail.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/12.
//

import Foundation

/// 完整卡片详情（API v0/card/{id}?show=all 返回结构）
struct CardFullDetail: Codable {
    /// 官方数据库唯一标识符
    let cid: Int
    /// 卡片密码（ID）
    let id: Int
    /// YGOPro 中文名称
    let cnName: String?
    /// 官方简体中文名称
    let scName: String?
    /// Master Duel 中文名称
    let mdName: String?
    /// NWBBS 论坛名称
    let nwbbsN: String?
    /// CNOCG 论坛名称
    let cnocgN: String?
    /// 日文读音
    let jpRuby: String?
    /// 日文名称
    let jpName: String?
    /// 英文名称
    let enName: String?
    /// 卡片文本信息
    let text: CardText?
    /// 卡片数值数据
    let data: CardData?
    /// FAQ 列表
    let faqs: [CardQA]?
    /// 补充调整
    let supplement: CardSupplement?
    /// 日文卡包发售信息
    let jppacks: [CardPack]?
    /// 英文卡包发售信息
    let enpacks: [CardPack]?
    /// 可用性信息
    let avail: CardAvailability?
    
    enum CodingKeys: String, CodingKey {
        case cid, id, text, data, faqs, supplement, jppacks, enpacks, avail
        case cnName = "cn_name"
        case scName = "sc_name"
        case mdName = "md_name"
        case nwbbsN = "nwbbs_n"
        case cnocgN = "cnocg_n"
        case jpRuby = "jp_ruby"
        case jpName = "jp_name"
        case enName = "en_name"
    }
}

/// 补充调整
struct CardSupplement: Codable {
    let refer: [String: Bool]?
    let text: String?
    let date: String?

    /// 清理 HTML 标签的说明文本
    var cleanText: String {
        guard var raw = text else { return "" }
        raw = raw.replacingOccurrences(of: "<hr\\s*/?>", with: "\n\n", options: .regularExpression)
        raw = raw.replacingOccurrences(of: "<li\\s+class=\"about\">", with: "\n", options: .regularExpression)
        raw = raw.replacingOccurrences(of: "<li>", with: "• ")
        raw = raw.replacingOccurrences(of: "</li>", with: "\n")
        raw = raw.replacingOccurrences(of: "<ul>", with: "")
        raw = raw.replacingOccurrences(of: "</ul>", with: "")
        raw = raw.replacingOccurrences(of: "<br>", with: "\n")
        raw = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        raw = raw.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 卡片 FAQ
struct CardQA: Codable, Identifiable {
    /// FAQ ID
    let fid: String
    /// 标题
    let title: String
    /// 日期
    let date: String?
    /// 问题
    let question: String
    /// 答案
    let answer: String
    
    var id: String { fid }
    
    enum CodingKeys: String, CodingKey {
        case fid, title, date, question, answer
    }
    
    /// 清理 HTML 标签的标题
    var cleanTitle: String {
        title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    /// 清理 HTML 标签的问题
    var cleanQuestion: String {
        question.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    /// 清理 HTML 标签的答案
    var cleanAnswer: String {
        answer.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

/// 单个卡包发售信息
struct CardPack: Codable, Identifiable {
    /// 卡包 ID
    let pid: String
    /// 卡包名称
    let name: String
    /// 发售日期
    let date: String
    /// 卡片编号
    let setid: String?
    
    var id: String { pid }
}

/// 卡片可用性信息
struct CardAvailability: Codable {
    let ocg: Int?
    let tcg: Int?
}
