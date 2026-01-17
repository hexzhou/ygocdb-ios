//
//  CardFilterView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/15.
//

import SwiftUI
import Combine

/// 卡片筛选类别（用于切换显示不同的筛选选项）
enum CardFilterCategory: String, CaseIterable {
    case monster = "怪兽"
    case spell = "魔法"
    case trap = "陷阱"
}

/// 卡片筛选条件
class CardFilter: ObservableObject {
    // 当前选中的筛选类别（仅用于UI切换，不作为筛选条件）
    @Published var selectedCategory: CardFilterCategory = .monster
    
    // 怪兽种类（通常/效果/融合/仪式/同调/超量/链接）
    @Published var selectedMonsterCategories: Set<CardType> = []
    
    // 怪兽能力（灵摆/调整/反转/卡通/灵魂/同盟/二重）
    @Published var selectedMonsterAbilities: Set<CardType> = []
    
    // 等级/阶级/Link值
    @Published var selectedLevels: Set<Int> = []
    
    // 魔法子类型
    @Published var selectedSpellTypes: Set<CardType> = []
    
    // 陷阱子类型
    @Published var selectedTrapTypes: Set<CardType> = []
    
    // 种族（仅怪兽）
    @Published var selectedRaces: Set<CardRace> = []
    
    // 属性（仅怪兽）
    @Published var selectedAttributes: Set<CardAttribute> = []
    
    /// 是否有激活的筛选条件（只检查具体的子筛选项）
    var hasActiveFilters: Bool {
        !selectedMonsterCategories.isEmpty ||
        !selectedMonsterAbilities.isEmpty ||
        !selectedLevels.isEmpty ||
        !selectedSpellTypes.isEmpty ||
        !selectedTrapTypes.isEmpty ||
        !selectedRaces.isEmpty ||
        !selectedAttributes.isEmpty
    }
    
    /// 是否有怪兽相关的筛选条件
    var hasMonsterFilters: Bool {
        !selectedMonsterCategories.isEmpty ||
        !selectedMonsterAbilities.isEmpty ||
        !selectedLevels.isEmpty ||
        !selectedRaces.isEmpty ||
        !selectedAttributes.isEmpty
    }
    
    /// 是否有魔法相关的筛选条件
    var hasSpellFilters: Bool {
        !selectedSpellTypes.isEmpty
    }
    
    /// 是否有陷阱相关的筛选条件
    var hasTrapFilters: Bool {
        !selectedTrapTypes.isEmpty
    }
    
    /// 重置所有筛选（保留主类型）
    func reset() {
        selectedMonsterCategories = []
        selectedMonsterAbilities = []
        selectedLevels = []
        selectedSpellTypes = []
        selectedTrapTypes = []
        selectedRaces = []
        selectedAttributes = []
    }
    
    /// 应用筛选到卡片列表
    func apply(to cards: [Card]) -> [Card] {
        // 如果没有任何筛选条件，直接返回原列表
        if !hasActiveFilters {
            return cards
        }
        
        return cards.filter { card in
            let cardType = card.cardType
            
            // 根据卡片类型应用对应的筛选条件
            if cardType.isMonster {
                // 怪兽卡：检查是否有怪兽筛选条件
                if hasMonsterFilters {
                    // 怪兽种类筛选
                    if !selectedMonsterCategories.isEmpty {
                        let hasMatchingCategory = selectedMonsterCategories.contains { category in
                            cardType.contains(category)
                        }
                        if !hasMatchingCategory { return false }
                    }
                    
                    // 怪兽能力筛选
                    if !selectedMonsterAbilities.isEmpty {
                        let hasMatchingAbility = selectedMonsterAbilities.contains { ability in
                            cardType.contains(ability)
                        }
                        if !hasMatchingAbility { return false }
                    }
                    
                    // 等级筛选
                    if !selectedLevels.isEmpty {
                        let level = card.data?.level ?? 0
                        let actualLevel = level & 0xFF  // 取低8位作为等级
                        if !selectedLevels.contains(actualLevel) { return false }
                    }
                    
                    // 种族筛选
                    if !selectedRaces.isEmpty {
                        guard let race = card.cardRace else { return false }
                        if !selectedRaces.contains(race) { return false }
                    }
                    
                    // 属性筛选
                    if !selectedAttributes.isEmpty {
                        guard let attr = card.cardAttribute else { return false }
                        if !selectedAttributes.contains(attr) { return false }
                    }
                    
                    return true
                } else {
                    // 没有怪兽筛选条件，但有其他类型的筛选条件时，不显示怪兽
                    return !hasSpellFilters && !hasTrapFilters
                }
            } else if cardType.isSpell {
                // 魔法卡：检查是否有魔法筛选条件
                if hasSpellFilters {
                    // 魔法子类型筛选
                    let hasMatchingType = selectedSpellTypes.contains { subType in
                        cardType.contains(subType)
                    }
                    return hasMatchingType
                } else {
                    // 没有魔法筛选条件，但有其他类型的筛选条件时，不显示魔法
                    return !hasMonsterFilters && !hasTrapFilters
                }
            } else if cardType.isTrap {
                // 陷阱卡：检查是否有陷阱筛选条件
                if hasTrapFilters {
                    // 陷阱子类型筛选
                    let hasMatchingType = selectedTrapTypes.contains { subType in
                        cardType.contains(subType)
                    }
                    return hasMatchingType
                } else {
                    // 没有陷阱筛选条件，但有其他类型的筛选条件时，不显示陷阱
                    return !hasMonsterFilters && !hasSpellFilters
                }
            }
            
            // 如果卡片类型不是怪兽/魔法/陷阱，不显示
            return false
        }
    }
}

/// 卡片筛选视图
struct CardFilterView: View {
    @ObservedObject var filter: CardFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 类别选择器（用于切换显示不同的筛选选项）
                Picker("类别", selection: $filter.selectedCategory) {
                    ForEach(CardFilterCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Divider()
                
                // 根据选中的类别显示对应的筛选选项
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch filter.selectedCategory {
                        case .monster:
                            MonsterFilterContent(filter: filter)
                        case .spell:
                            SpellFilterContent(filter: filter)
                        case .trap:
                            TrapFilterContent(filter: filter)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        filter.reset()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// 怪兽筛选内容
struct MonsterFilterContent: View {
    @ObservedObject var filter: CardFilter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 种类
            FilterSectionView(title: "种类") {
                MonsterCategorySection(selectedCategories: $filter.selectedMonsterCategories)
            }
            
            // 能力
            FilterSectionView(title: "能力") {
                MonsterAbilitySection(selectedAbilities: $filter.selectedMonsterAbilities)
            }
            
            // 等级/阶级/Link值
            FilterSectionView(title: "等级/阶级/Link值") {
                LevelFilterSection(selectedLevels: $filter.selectedLevels)
            }
            
            // 种族
            FilterSectionView(title: "种族") {
                RaceFilterSection(selectedRaces: $filter.selectedRaces)
            }
            
            // 属性
            FilterSectionView(title: "属性") {
                AttributeFilterSection(selectedAttributes: $filter.selectedAttributes)
            }
        }
    }
}

/// 怪兽种类筛选区（通常/效果/融合/仪式/同调/超量/链接）
struct MonsterCategorySection: View {
    @Binding var selectedCategories: Set<CardType>
    
    private let categories: [(String, CardType)] = [
        ("通常", .normal),
        ("效果", .effect),
        ("融合", .fusion),
        ("仪式", .ritual),
        ("同调", .synchro),
        ("超量", .xyz),
        ("链接", .link)
    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(categories, id: \.0) { name, type in
                FilterChip(
                    title: name,
                    isSelected: selectedCategories.contains(type)
                ) {
                    if selectedCategories.contains(type) {
                        selectedCategories.remove(type)
                    } else {
                        selectedCategories.insert(type)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// 怪兽能力筛选区（灵摆/调整/反转/卡通/灵魂/同盟/二重）
struct MonsterAbilitySection: View {
    @Binding var selectedAbilities: Set<CardType>
    
    private let abilities: [(String, CardType)] = [
        ("灵摆", .pendulum),
        ("调整", .tuner),
        ("反转", .flip),
        ("卡通", .toon),
        ("灵魂", .spirit),
        ("同盟", .union),
        ("二重", .dual)
    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(abilities, id: \.0) { name, type in
                FilterChip(
                    title: name,
                    isSelected: selectedAbilities.contains(type)
                ) {
                    if selectedAbilities.contains(type) {
                        selectedAbilities.remove(type)
                    } else {
                        selectedAbilities.insert(type)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// 等级/阶级/Link值筛选区
struct LevelFilterSection: View {
    @Binding var selectedLevels: Set<Int>
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(1...12, id: \.self) { level in
                FilterChip(
                    title: "\(level)",
                    isSelected: selectedLevels.contains(level)
                ) {
                    if selectedLevels.contains(level) {
                        selectedLevels.remove(level)
                    } else {
                        selectedLevels.insert(level)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// 魔法筛选内容
struct SpellFilterContent: View {
    @ObservedObject var filter: CardFilter
    
    private let spellTypes: [(String, CardType)] = [
        ("通常", CardType(rawValue: 0)),  // 通常魔法没有额外 flag
        ("速攻", .quickPlay),
        ("永续", .continuous),
        ("装备", .equip),
        ("场地", .field),
        ("仪式", .ritual)
    ]
    
    var body: some View {
        FilterSectionView(title: "魔法类型") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(spellTypes, id: \.0) { name, type in
                    FilterChip(
                        title: name,
                        isSelected: filter.selectedSpellTypes.contains(type)
                    ) {
                        if filter.selectedSpellTypes.contains(type) {
                            filter.selectedSpellTypes.remove(type)
                        } else {
                            filter.selectedSpellTypes.insert(type)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// 陷阱筛选内容
struct TrapFilterContent: View {
    @ObservedObject var filter: CardFilter
    
    private let trapTypes: [(String, CardType)] = [
        ("通常", CardType(rawValue: 0)),  // 通常陷阱没有额外 flag
        ("永续", .continuous),
        ("反击", .counter)
    ]
    
    var body: some View {
        FilterSectionView(title: "陷阱类型") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(trapTypes, id: \.0) { name, type in
                    FilterChip(
                        title: name,
                        isSelected: filter.selectedTrapTypes.contains(type)
                    ) {
                        if filter.selectedTrapTypes.contains(type) {
                            filter.selectedTrapTypes.remove(type)
                        } else {
                            filter.selectedTrapTypes.insert(type)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// 筛选区域视图
struct FilterSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            content
        }
    }
}

/// 种族筛选区
struct RaceFilterSection: View {
    @Binding var selectedRaces: Set<CardRace>
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(CardRace.allCases, id: \.self) { race in
                FilterChip(
                    title: race.displayName,
                    isSelected: selectedRaces.contains(race)
                ) {
                    if selectedRaces.contains(race) {
                        selectedRaces.remove(race)
                    } else {
                        selectedRaces.insert(race)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// 属性筛选区
struct AttributeFilterSection: View {
    @Binding var selectedAttributes: Set<CardAttribute>
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(CardAttribute.allCases, id: \.self) { attr in
                FilterChip(
                    title: attr.displayName,
                    isSelected: selectedAttributes.contains(attr)
                ) {
                    if selectedAttributes.contains(attr) {
                        selectedAttributes.remove(attr)
                    } else {
                        selectedAttributes.insert(attr)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// 筛选标签
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CardFilterView(filter: CardFilter())
}
