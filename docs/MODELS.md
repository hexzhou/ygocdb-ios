# 数据模型文档

## 核心模型

### Card

卡片主模型，匹配 ygocdb API 返回的 JSON 结构。

```swift
struct Card: Codable, Identifiable {
    let cid: Int        // 官方数据库唯一标识符
    let id: Int         // 卡片密码
    let cnName: String? // 中文名称（YGOPro 译名）
    let scName: String? // 官方简体中文名称
    let mdName: String? // Master Duel 中文名称
    let nwbbsN: String? // NWBBS 论坛译名
    let cnocgN: String? // CNOCG 论坛译名
    let jpRuby: String? // 日文读音
    let jpName: String? // 日文名称
    let enName: String? // 英文名称
    let text: CardText? // 卡片文本信息
    let data: CardData? // 卡片数值数据
}
```

### CardText

卡片文本信息。

```swift
struct CardText: Codable {
    let types: String?  // 类型描述，如 "[怪兽|效果] 龙/暗\n[★7] 2500/2000"
    let pdesc: String?  // 灵摆效果描述
    let desc: String?   // 卡片效果/描述文本
}
```

### CardData

卡片数值数据。

```swift
struct CardData: Codable {
    let ot: Int?        // 发行范围（OCG/TCG）
    let setcode: Int?   // 系列代码
    let type: Int?      // 卡片类型位
    let atk: Int?       // 攻击力
    let def: Int?       // 防御力
    let level: Int?     // 等级/阶级/连接值
    let race: Int?      // 种族
    let attribute: Int? // 属性
}
```

## 类型位定义

### 卡片类型 (type)

| 位 | 值 | 说明 |
|----|-----|------|
| 0 | 0x1 | 怪兽 |
| 1 | 0x2 | 魔法 |
| 2 | 0x4 | 陷阱 |
| 4 | 0x10 | 通常 |
| 5 | 0x20 | 效果 |
| 6 | 0x40 | 融合 |
| 7 | 0x80 | 仪式 |
| 11 | 0x800 | 同调 |
| 21 | 0x200000 | 超量 |
| 22 | 0x400000 | 灵摆 |
| 24 | 0x1000000 | 连接 |

### 种族 (race)

| 值 | 说明 |
|----|------|
| 0x1 | 战士 |
| 0x2 | 魔法师 |
| 0x4 | 天使 |
| 0x8 | 恶魔 |
| 0x10 | 不死 |
| 0x20 | 机械 |
| 0x40 | 水 |
| 0x80 | 炎 |
| 0x100 | 岩石 |
| 0x200 | 鸟兽 |
| 0x400 | 植物 |
| 0x800 | 昆虫 |
| 0x1000 | 雷 |
| 0x2000 | 龙 |
| 0x4000 | 兽 |
| 0x8000 | 兽战士 |
| 0x10000 | 恐龙 |
| 0x20000 | 鱼 |
| 0x40000 | 海龙 |
| 0x80000 | 爬虫 |
| 0x100000 | 念动力 |
| 0x200000 | 幻神兽 |
| 0x400000 | 创造神 |
| 0x800000 | 幻龙 |
| 0x1000000 | 电子界 |
| 0x2000000 | 幻想魔 |

### 属性 (attribute)

| 值 | 说明 |
|----|------|
| 0x1 | 地 |
| 0x2 | 水 |
| 0x4 | 炎 |
| 0x8 | 风 |
| 0x10 | 光 |
| 0x20 | 暗 |
| 0x40 | 神 |

## 设置模型

### NetworkMode

```swift
enum NetworkMode: String {
    case online = "在线"
    case offline = "离线"
}
```

### UpdateMode

```swift
enum UpdateMode: String {
    case automatic = "自动更新"
    case manual = "手动更新"
}
```

### AutoUpdatePolicy

```swift
enum AutoUpdatePolicy: String {
    case everyHour = "每隔1小时"
    case every24Hours = "每隔24小时"
    case every7Days = "每隔7天"
}
```

### CardNameSource

译名来源选项。

```swift
enum CardNameSource: String {
    case ygopro = "YGOPRO"
    case sc = "简体中文"
    case masterDuel = "Master Duel"
    case nwbbs = "NWBBS"
    case cnocg = "CNOCG"
}
```

### CardImageLanguage

卡图语言选项。

```swift
enum CardImageLanguage: String {
    case ygopro = "YGOPRO"
    case sc = "简体中文"
    case jp = "日文"
    case en = "英文"
}
```
