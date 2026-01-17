//
//  CardConstants.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/15.
//

import Foundation

// MARK: - 卡片类型 (type)

/// 卡片类型位掩码
struct CardType: OptionSet, Hashable {
    let rawValue: Int
    
    // 基础类型
    static let monster     = CardType(rawValue: 0x1)       // 怪兽
    static let spell       = CardType(rawValue: 0x2)       // 魔法
    static let trap        = CardType(rawValue: 0x4)       // 陷阱
    
    // 怪兽子类型
    static let normal      = CardType(rawValue: 0x10)      // 通常
    static let effect      = CardType(rawValue: 0x20)      // 效果
    static let fusion      = CardType(rawValue: 0x40)      // 融合
    static let ritual      = CardType(rawValue: 0x80)      // 仪式
    static let trapMonster = CardType(rawValue: 0x100)     // 陷阱怪兽
    static let spirit      = CardType(rawValue: 0x200)     // 灵魂
    static let union       = CardType(rawValue: 0x400)     // 同盟
    static let dual        = CardType(rawValue: 0x800)     // 二重
    static let tuner       = CardType(rawValue: 0x1000)    // 调整
    static let synchro     = CardType(rawValue: 0x2000)    // 同调
    static let token       = CardType(rawValue: 0x4000)    // 衍生物
    static let quickEffect = CardType(rawValue: 0x8000)    // 速攻效果(怪兽)
    static let pendulum    = CardType(rawValue: 0x1000000) // 灵摆
    static let xyz         = CardType(rawValue: 0x800000)  // 超量
    static let link        = CardType(rawValue: 0x4000000) // 链接
    static let flip        = CardType(rawValue: 0x200000)  // 反转
    static let toon        = CardType(rawValue: 0x400000)  // 卡通
    static let spsummon    = CardType(rawValue: 0x2000000) // 特殊召唤
    
    // 魔法/陷阱子类型
    static let quickPlay   = CardType(rawValue: 0x10000)   // 速攻(魔法)
    static let continuous  = CardType(rawValue: 0x20000)   // 永续
    static let equip       = CardType(rawValue: 0x40000)   // 装备
    static let field       = CardType(rawValue: 0x80000)   // 场地
    static let counter     = CardType(rawValue: 0x100000)  // 反击(陷阱)
    
    // 常用组合
    static let normalMonster: CardType     = [.monster, .normal]           // 通常怪兽 = 17
    static let effectMonster: CardType     = [.monster, .effect]           // 效果怪兽 = 33
    static let fusionMonster: CardType     = [.monster, .fusion]           // 融合怪兽 = 65
    static let fusionEffect: CardType      = [.monster, .fusion, .effect]  // 融合效果 = 97
    static let ritualMonster: CardType     = [.monster, .ritual]           // 仪式怪兽 = 129
    static let ritualEffect: CardType      = [.monster, .ritual, .effect]  // 仪式效果 = 161
    static let synchroMonster: CardType    = [.monster, .synchro]          // 同调怪兽
    static let synchroEffect: CardType     = [.monster, .synchro, .effect] // 同调效果
    static let xyzMonster: CardType        = [.monster, .xyz]              // 超量怪兽
    static let xyzEffect: CardType         = [.monster, .xyz, .effect]     // 超量效果
    static let pendulumMonster: CardType   = [.monster, .pendulum]         // 灵摆怪兽
    static let linkMonster: CardType       = [.monster, .link]             // 链接怪兽
    static let linkEffect: CardType        = [.monster, .link, .effect]    // 链接效果
    static let tunerMonster: CardType      = [.monster, .tuner]            // 调整怪兽
    static let tunerEffect: CardType       = [.monster, .tuner, .effect]   // 调整效果
    
    static let quickPlaySpell: CardType    = [.spell, .quickPlay]          // 速攻魔法 = 65538
    static let continuousSpell: CardType   = [.spell, .continuous]         // 永续魔法 = 131074
    static let equipSpell: CardType        = [.spell, .equip]              // 装备魔法 = 262146
    static let fieldSpell: CardType        = [.spell, .field]              // 场地魔法 = 524290
    static let ritualSpell: CardType       = [.spell, .ritual]             // 仪式魔法
    
    static let continuousTrap: CardType    = [.trap, .continuous]          // 永续陷阱
    static let counterTrap: CardType       = [.trap, .counter]             // 反击陷阱 = 1048580
    
    /// 判断是否是怪兽
    var isMonster: Bool { contains(.monster) }
    
    /// 判断是否是魔法
    var isSpell: Bool { contains(.spell) }
    
    /// 判断是否是陷阱
    var isTrap: Bool { contains(.trap) }
    
    /// 获取显示名称
    var displayName: String {
        var parts: [String] = []
        
        // 基础类型
        if contains(.monster) { parts.append("怪兽") }
        if contains(.spell) { parts.append("魔法") }
        if contains(.trap) { parts.append("陷阱") }
        
        // 子类型
        if contains(.normal) { parts.append("通常") }
        if contains(.effect) { parts.append("效果") }
        if contains(.fusion) { parts.append("融合") }
        if contains(.ritual) { parts.append("仪式") }
        if contains(.synchro) { parts.append("同调") }
        if contains(.xyz) { parts.append("超量") }
        if contains(.pendulum) { parts.append("灵摆") }
        if contains(.link) { parts.append("链接") }
        if contains(.tuner) { parts.append("调整") }
        if contains(.spirit) { parts.append("灵魂") }
        if contains(.union) { parts.append("同盟") }
        if contains(.dual) { parts.append("二重") }
        if contains(.flip) { parts.append("反转") }
        if contains(.toon) { parts.append("卡通") }
        if contains(.spsummon) { parts.append("特殊召唤") }
        if contains(.quickPlay) { parts.append("速攻") }
        if contains(.continuous) { parts.append("永续") }
        if contains(.equip) { parts.append("装备") }
        if contains(.field) { parts.append("场地") }
        if contains(.counter) { parts.append("反击") }
        
        return parts.joined(separator: "/")
    }
}

// MARK: - 种族 (race)

/// 怪兽种族
enum CardRace: Int, CaseIterable {
    case warrior      = 0x1       // 战士
    case spellcaster  = 0x2       // 魔法师
    case fairy        = 0x4       // 天使
    case fiend        = 0x8       // 恶魔
    case zombie       = 0x10      // 不死
    case machine      = 0x20      // 机械
    case aqua         = 0x40      // 水
    case pyro         = 0x80      // 炎
    case rock         = 0x100     // 岩石
    case windBeast    = 0x200     // 鸟兽
    case plant        = 0x400     // 植物
    case insect       = 0x800     // 昆虫
    case thunder      = 0x1000    // 雷
    case dragon       = 0x2000    // 龙
    case beast        = 0x4000    // 兽
    case beastWarrior = 0x8000    // 兽战士
    case dinosaur     = 0x10000   // 恐龙
    case fish         = 0x20000   // 鱼
    case seaSerpent   = 0x40000   // 海龙
    case reptile      = 0x80000   // 爬虫
    case psychic      = 0x100000  // 念动力
    case divine       = 0x200000  // 幻神兽
    case creatorGod   = 0x400000  // 创造神
    case wyrm         = 0x800000  // 幻龙
    case cyberse      = 0x1000000 // 电子界
    case illusion     = 0x2000000 // 幻想魔
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .warrior:      return "战士"
        case .spellcaster:  return "魔法师"
        case .fairy:        return "天使"
        case .fiend:        return "恶魔"
        case .zombie:       return "不死"
        case .machine:      return "机械"
        case .aqua:         return "水"
        case .pyro:         return "炎"
        case .rock:         return "岩石"
        case .windBeast:    return "鸟兽"
        case .plant:        return "植物"
        case .insect:       return "昆虫"
        case .thunder:      return "雷"
        case .dragon:       return "龙"
        case .beast:        return "兽"
        case .beastWarrior: return "兽战士"
        case .dinosaur:     return "恐龙"
        case .fish:         return "鱼"
        case .seaSerpent:   return "海龙"
        case .reptile:      return "爬虫"
        case .psychic:      return "念动力"
        case .divine:       return "幻神兽"
        case .creatorGod:   return "创造神"
        case .wyrm:         return "幻龙"
        case .cyberse:      return "电子界"
        case .illusion:     return "幻想魔"
        }
    }
    
    /// 从原始值获取种族
    static func from(rawValue: Int) -> CardRace? {
        return CardRace(rawValue: rawValue)
    }
}

// MARK: - 属性 (attribute)

/// 怪兽属性
enum CardAttribute: Int, CaseIterable {
    case earth  = 0x01  // 地
    case water  = 0x02  // 水
    case fire   = 0x04  // 炎
    case wind   = 0x08  // 风
    case light  = 0x10  // 光
    case dark   = 0x20  // 暗
    case divine = 0x40  // 神
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .earth:  return "地"
        case .water:  return "水"
        case .fire:   return "炎"
        case .wind:   return "风"
        case .light:  return "光"
        case .dark:   return "暗"
        case .divine: return "神"
        }
    }
    
    /// 颜色
    var color: String {
        switch self {
        case .earth:  return "#8B4513"  // 棕色
        case .water:  return "#4169E1"  // 蓝色
        case .fire:   return "#DC143C"  // 红色
        case .wind:   return "#32CD32"  // 绿色
        case .light:  return "#FFD700"  // 金色
        case .dark:   return "#8B008B"  // 紫色
        case .divine: return "#FFD700"  // 金色
        }
    }
    
    /// 从原始值获取属性
    static func from(rawValue: Int) -> CardAttribute? {
        return CardAttribute(rawValue: rawValue)
    }
}

// MARK: - 发行区域 (ot)

/// 发行区域
struct CardOT: OptionSet, Hashable {
    let rawValue: Int
    
    static let ocg  = CardOT(rawValue: 0x1)  // OCG
    static let tcg  = CardOT(rawValue: 0x2)  // TCG
    static let md   = CardOT(rawValue: 0x8)  // Master Duel
    
    static let all: CardOT = [.ocg, .tcg, .md]
    static let ocgTcg: CardOT = [.ocg, .tcg]
    
    /// 显示名称
    var displayName: String {
        var parts: [String] = []
        if contains(.ocg) { parts.append("OCG") }
        if contains(.tcg) { parts.append("TCG") }
        if contains(.md) { parts.append("MD") }
        return parts.joined(separator: "/")
    }
}

// MARK: - 辅助扩展

extension Card {
    /// 获取卡片类型
    var cardType: CardType {
        CardType(rawValue: data?.type ?? 0)
    }
    
    /// 获取种族
    var cardRace: CardRace? {
        guard let race = data?.race else { return nil }
        return CardRace.from(rawValue: race)
    }
    
    /// 获取属性
    var cardAttribute: CardAttribute? {
        guard let attr = data?.attribute else { return nil }
        return CardAttribute.from(rawValue: attr)
    }
    
    /// 获取发行区域
    var cardOT: CardOT {
        CardOT(rawValue: data?.ot ?? 0)
    }
    
    /// 获取 type 原始值
    var type: Int {
        data?.type ?? 0
    }
    
    /// 获取 race 原始值
    var race: Int {
        data?.race ?? 0
    }
    
    /// 获取 attribute 原始值
    var attribute: Int {
        data?.attribute ?? 0
    }
    
    /// 获取 ot 原始值
    var ot: Int {
        data?.ot ?? 0
    }
}
