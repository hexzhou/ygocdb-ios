//
//  Card.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation

/// 卡片数据模型，匹配 ygocdb API 返回的 JSON 结构
struct Card: Codable, Identifiable {
    /// 官方数据库唯一标识符
    let cid: Int
    /// 卡片密码（ID）
    let id: Int
    /// 中文名称（YGOPro 译名）
    let cnName: String?
    /// 官方简体中文名称
    let scName: String?
    /// Master Duel 中文名称
    let mdName: String?
    /// NWBBS 论坛译名
    let nwbbsN: String?
    /// CNOCG 论坛译名
    let cnocgN: String?
    /// 日文读音
    let jpRuby: String?
    /// 日文名称
    let jpName: String?
    /// 英文名称
    let enName: String?
    /// 卡片文本信息（可选，部分卡片可能没有）
    let text: CardText?
    /// 卡片数值数据（可选，部分卡片可能没有）
    let data: CardData?
    
    enum CodingKeys: String, CodingKey {
        case cid, id, text, data
        case cnName = "cn_name"
        case scName = "sc_name"
        case mdName = "md_name"
        case nwbbsN = "nwbbs_n"
        case cnocgN = "cnocg_n"
        case jpRuby = "jp_ruby"
        case jpName = "jp_name"
        case enName = "en_name"
    }
    
    /// 获取显示用的卡片名称（优先中文名）
    var displayName: String {
        cnName ?? scName ?? jpName ?? enName ?? "未知卡片"
    }
    
    /// 卡图 URL（缩略图 82x120）
    var thumbnailURL: URL? {
        URL(string: "https://cdn.233.momobako.com/ygopro/pics/\(id).jpg!thumb2")
    }
    
    /// 卡图 URL（半尺寸 200x290）
    var halfImageURL: URL? {
        URL(string: "https://cdn.233.momobako.com/ygopro/pics/\(id).jpg!half")
    }
    
    /// 卡图 URL（完整尺寸）
    var fullImageURL: URL? {
        URL(string: "https://cdn.233.momobako.com/ygopro/pics/\(id).jpg")
    }
    
    /// 安全获取类型描述
    var typesDisplay: String {
        text?.typesDisplay ?? ""
    }
    
    /// 安全获取效果描述
    var descDisplay: String {
        text?.descDisplay ?? ""
    }
    
    /// 安全获取灵摆效果
    var pdescDisplay: String {
        text?.pdescDisplay ?? ""
    }
}

/// 卡片文本信息
struct CardText: Codable {
    /// 卡片类型描述，例如 "[怪兽|效果] 龙/暗\n[★7] 2500/2000"
    let types: String?
    /// 灵摆效果描述
    let pdesc: String?
    /// 卡片效果/描述文本
    let desc: String?
    
    /// 获取类型描述，带默认值
    var typesDisplay: String {
        types ?? ""
    }
    
    /// 获取效果描述，带默认值
    var descDisplay: String {
        desc ?? ""
    }
    
    /// 获取灵摆效果，带默认值
    var pdescDisplay: String {
        pdesc ?? ""
    }
}

/// 卡片数值数据
struct CardData: Codable {
    /// 发行范围（OCG/TCG）
    let ot: Int?
    /// 系列代码
    let setcode: Int?
    /// 卡片类型位（怪兽/魔法/陷阱等）
    let type: Int?
    /// 攻击力
    let atk: Int?
    /// 防御力
    let def: Int?
    /// 等级/阶级/连接值/灵摆刻度
    let level: Int?
    /// 种族
    let race: Int?
    /// 属性
    let attribute: Int?
    
    /// 是否为怪兽卡
    var isMonster: Bool {
        (type ?? 0) & 0x1 != 0
    }
    
    /// 是否为魔法卡
    var isSpell: Bool {
        (type ?? 0) & 0x2 != 0
    }
    
    /// 是否为陷阱卡
    var isTrap: Bool {
        (type ?? 0) & 0x4 != 0
    }
    
    /// 获取显示用的攻击力文本
    var atkText: String {
        guard let atk = atk else { return "-" }
        return atk == -2 ? "?" : String(atk)
    }
    
    /// 获取显示用的防御力文本
    var defText: String {
        guard let def = def else { return "-" }
        return def == -2 ? "?" : String(def)
    }
}

/// 卡片数据库响应模型（用于 cards.json）
typealias CardDatabase = [String: Card]
