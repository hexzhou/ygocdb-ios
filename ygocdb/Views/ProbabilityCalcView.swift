//
//  ProbabilityCalcView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/30.
//

import SwiftUI
import UIKit

/// 概率计算主页面
struct ProbabilityCalcView: View {
    @ObservedObject var deckViewModel: DeckBuilderViewModel
    let deckId: UUID
    @StateObject private var calcViewModel = ProbabilityCalcViewModel()

    @State private var scenarios: [ProbabilityScenario] = []
    @State private var editingScenario: ProbabilityScenario?
    @State private var deckSnapshot: Deck?

    private var currentDeck: Deck? {
        deckSnapshot ?? deckViewModel.decks.first(where: { $0.id == deckId }) ?? deckViewModel.currentDeck
    }

    var body: some View {
        List {
            if let deck = currentDeck {
                // 顶部卡组信息卡片 - 现代化设计
                Section {
                    HStack(spacing: 16) {
                        // 装饰性图标
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 50, height: 50)
                            Image(systemName: "percent")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(deck.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 12) {
                                Label("\(deck.mainDeckCount)", systemImage: "rectangle.stack")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Label("\(deck.extraDeckCount)", systemImage: "square.stack.3d.up")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                Label("\(deck.sideDeckCount)", systemImage: "square.stack")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // 场景列表区域
                Section(header: Text("场景")) {
                    if scenarios.isEmpty {
                        // 空状态 - 更友好的提示
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 36))
                                .foregroundStyle(LinearGradient(
                                    colors: [.gray.opacity(0.4), .gray.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                            Text("暂无计算场景")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("点击下方按钮创建概率计算场景")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(scenarios) { scenario in
                            ProbabilityScenarioRow(
                                scenario: scenario,
                                result: calcViewModel.results[scenario.id],
                                isCalculating: calcViewModel.calculating.contains(scenario.id),
                                onRecalculate: {
                                    calcViewModel.recalculate(scenario: scenario, deck: deck)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingScenario = scenario
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteScenario(scenario)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    duplicateScenarioAndEdit(scenario)
                                } label: {
                                    Label("复制", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    duplicateScenarioAndEdit(scenario)
                                } label: {
                                    Label("复制", systemImage: "doc.on.doc")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }

                // 新建场景按钮 - 更有吸引力的设计
                Section {
                    Button {
                        createNewScenario()
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            }
                            
                            Text("新建场景")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("未找到卡组")
            }
        }
        .navigationTitle("概率计算")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshDeck()
        }
        .onReceive(deckViewModel.$decks) { _ in
            refreshDeck()
        }
        .sheet(item: $editingScenario, onDismiss: { editingScenario = nil }) { scenario in
            if let deck = currentDeck {
                ProbabilityScenarioEditor(
                    deck: deck,
                    scenario: scenario,
                    onSave: { updated in
                        saveScenario(updated, for: deck)
                    },
                    onPreview: { draft, completion in
                        calcViewModel.calculatePreview(scenario: draft, deck: deck, completion: completion)
                    }
                )
            } else {
                ProgressView()
            }
        }
    }

    private func refreshDeck() {
        if let deck = deckViewModel.decks.first(where: { $0.id == deckId }) ?? deckViewModel.currentDeck {
            deckSnapshot = deck
            scenarios = deck.probabilityScenarios
            calcViewModel.recalculateAll(scenarios: scenarios, deck: deck)
        }
    }

    private func saveScenario(_ scenario: ProbabilityScenario, for deck: Deck) {
        if let index = scenarios.firstIndex(where: { $0.id == scenario.id }) {
            scenarios[index] = scenario
        } else {
            scenarios.append(scenario)
        }
        deckViewModel.updateProbabilityScenarios(scenarios, for: deck)
        calcViewModel.recalculate(scenario: scenario, deck: deck)
    }

    private func deleteScenario(_ scenario: ProbabilityScenario) {
        scenarios.removeAll { $0.id == scenario.id }
        calcViewModel.results.removeValue(forKey: scenario.id)
        if let deck = currentDeck {
            deckViewModel.updateProbabilityScenarios(scenarios, for: deck)
        }
    }

    private func duplicateScenarioAndEdit(_ scenario: ProbabilityScenario) {
        var copy = scenario
        copy.id = UUID()
        copy.name = uniqueCopyName(for: scenario)
        scenarios.append(copy)
        if let deck = currentDeck {
            deckViewModel.updateProbabilityScenarios(scenarios, for: deck)
            calcViewModel.recalculate(scenario: copy, deck: deck)
        }
        editingScenario = copy
    }

    private func uniqueCopyName(for scenario: ProbabilityScenario) -> String {
        let base = "\(scenario.name) 副本"
        var name = base
        var suffix = 1
        while scenarios.contains(where: { $0.name == name }) {
            suffix += 1
            name = "\(base) \(suffix)"
        }
        return name
    }

    private func createNewScenario() {
        var scenario = ProbabilityScenario.defaultScenario()
        // 确保名称不重复
        let baseName = scenario.name
        var suffix = 1
        while scenarios.contains(where: { $0.name == scenario.name }) {
            suffix += 1
            scenario.name = "\(baseName) \(suffix)"
        }
        scenarios.append(scenario)
        if let deck = currentDeck {
            deckViewModel.updateProbabilityScenarios(scenarios, for: deck)
            calcViewModel.recalculate(scenario: scenario, deck: deck)
        }
        editingScenario = scenario
    }
}

/// 场景列表行 - 简洁的现代化设计
private struct ProbabilityScenarioRow: View {
    let scenario: ProbabilityScenario
    let result: ProbabilityDisplayResult?
    let isCalculating: Bool
    let onRecalculate: () -> Void

    /// 概率值转换为颜色
    private var probabilityColor: Color {
        guard let base = result?.base else { return .secondary }
        let prob = base.probability
        if prob >= 0.8 {
            return .green
        } else if prob >= 0.5 {
            return .orange
        } else if prob >= 0.3 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：场景信息
            VStack(alignment: .leading, spacing: 6) {
                // 场景名称
                HStack(spacing: 8) {
                    Circle()
                        .fill(probabilityColor)
                        .frame(width: 8, height: 8)
                    
                    Text(scenario.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                // 抽卡信息
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(scenario.draws) 张")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 右侧：概率显示
            if isCalculating {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let error = result?.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            } else if let base = result?.base {
                Text(formatProbability(base.probability))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(probabilityColor)
            } else {
                Text("--")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 右箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

/// 场景编辑 Sheet
private struct ProbabilityScenarioEditor: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProbabilityScenario
    @State private var previewResult: ProbabilityDisplayResult?
    @State private var isCalculating = false
    @State private var previewTask: Task<Void, Never>?
    @State private var pickingGroup: ProbabilityGroup?
    @State private var showConditionDetail = false
    private let conditionFieldId = "condition-field"

    let onSave: (ProbabilityScenario) -> Void
    let onPreview: (ProbabilityScenario, @escaping (ProbabilityDisplayResult) -> Void) -> Void

    init(
        deck: Deck,
        scenario: ProbabilityScenario,
        onSave: @escaping (ProbabilityScenario) -> Void,
        onPreview: @escaping (ProbabilityScenario, @escaping (ProbabilityDisplayResult) -> Void) -> Void
    ) {
        self.deck = deck
        self._draft = State(initialValue: scenario)
        self.onSave = onSave
        self.onPreview = onPreview
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                Form {
                // 基础设置区域
                Section(header: HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("基础设置")
                }) {
                    HStack(spacing: 12) {
                        // 装饰性图标
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.orange.opacity(0.15), Color.pink.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 40, height: 40)
                            Image(systemName: "percent")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        
                        TextField("场景名称", text: $draft.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)

                    Stepper(value: $draft.startingHand, in: 1...10) {
                        HStack {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("起手张数：\(draft.startingHand)")
                        }
                    }

                    Stepper(value: $draft.extraDraws, in: 0...10) {
                        HStack {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("额外抽卡：\(draft.extraDraws)")
                        }
                    }

                    Picker("计算方法", selection: $draft.method) {
                        ForEach(ProbabilityCalculationMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }

                    if draft.method == .monteCarlo || draft.method == .auto {
                        Stepper(value: $draft.simulations, in: 10000...300000, step: 10000) {
                            HStack {
                                Image(systemName: "cpu")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("模拟次数：\(draft.simulations)")
                            }
                        }
                    }
                }

                // 分组区域
                Section(header: HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("分组")
                }) {
                    ForEach($draft.groups) { $group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.label)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                TextField("分组名称", text: $group.name)
                            }
                            
                            HStack(spacing: 16) {
                                // 卡片数量
                                HStack(spacing: 4) {
                                    Image(systemName: "square.stack")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text("卡片数量：\(countForGroup(group))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // 选择卡片按钮
                                Button {
                                    pickingGroup = group
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 10))
                                        Text("选择卡片")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                removeGroup(group)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .disabled(draft.groups.count <= 1)
                        }
                    }

                    // 新增分组按钮
                    Button {
                        addGroup()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                            
                            Text("新增分组")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.groups.count >= 30)
                }

                // 条件区域
                Section(header: HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("条件")
                }) {
                    Menu {
                        ForEach(templates) { template in
                            Button(template.title) {
                                draft.condition = template.expression
                            }
                            .disabled(draft.groups.count < template.minGroups)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("使用模板")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        if draft.condition.isEmpty {
                            Text("高级表达式（如 a > 0 && b >= 1）")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                        }
                        DoneTextEditor(
                            text: $draft.condition,
                            onBeginEditing: { scrollToCondition(proxy) },
                            onDone: { dismissKeyboard() }
                        )
                        .frame(minHeight: 60)
                    }
                    .id(conditionFieldId)

                    Text("使用提示：a/b/c 对应分组顺序，支持 && || + - * / 以及括号。")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button {
                        showConditionDetail = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                            Text("查看详情")
                                .font(.caption)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }

                // 即时结果区域
                Section(header: HStack(spacing: 6) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("即时结果")
                }) {
                    if isCalculating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("计算中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let result = previewResult {
                        if let error = result.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        } else if let base = result.base {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("主卡组概率")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatProbability(base.probability))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(base.probability >= 0.5 ? .green : .orange)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("尚未计算")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("编辑场景")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            onSave(draft)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .keyboard) {
                        Button("完成") {
                            dismissKeyboard()
                        }
                    }
                }
                .modifier(KeyboardDismissModifier())
                .onAppear {
                    schedulePreview()
                }
                .onChange(of: draft) { _ in
                    schedulePreview()
                }
                .sheet(item: $pickingGroup, onDismiss: { pickingGroup = nil }) { group in
                    if let groupIndex = draft.groups.firstIndex(where: { $0.id == group.id }) {
                        CardPickerSheet(
                            title: "选择分组卡片",
                            cards: mainDeckCardCounts(),
                            selectedCardIds: Binding(
                                get: { Set(draft.groups[groupIndex].cardIds) },
                                set: { draft.groups[groupIndex].cardIds = Array($0) }
                            ),
                            disabledCardIds: usedCardIds(excluding: draft.groups[groupIndex].id)
                        )
                    } else {
                        Text("分组不存在")
                            .onAppear {
                                pickingGroup = nil
                            }
                    }
                }
                .sheet(isPresented: $showConditionDetail) {
                    ConditionDetailSheet(
                        condition: draft.condition,
                        groups: draft.groups,
                        previewResult: previewResult,
                        isCalculating: isCalculating
                    )
                }
            }
        }
    }

    private func scrollToCondition(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(conditionFieldId, anchor: .center)
            }
        }
    }

    private struct TemplateItem: Identifiable {
        let id = UUID()
        let title: String
        let expression: String
        let minGroups: Int
    }

    private var templates: [TemplateItem] {
        [
            TemplateItem(title: "至少 1 张 A", expression: "a > 0", minGroups: 1),
            TemplateItem(title: "至少 2 张 A", expression: "a >= 2", minGroups: 1),
            TemplateItem(title: "A 或 B 至少 1 张", expression: "a > 0 || b > 0", minGroups: 2),
            TemplateItem(title: "A 与 B 各至少 1 张", expression: "a > 0 && b > 0", minGroups: 2),
            TemplateItem(title: "A + B 至少 2 张", expression: "a + b >= 2", minGroups: 2)
        ]
    }

    private func schedulePreview() {
        previewTask?.cancel()
        isCalculating = true
        let currentDraft = draft
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            onPreview(currentDraft) { result in
                previewResult = result
                isCalculating = false
            }
        }
    }

    private func addGroup() {
        let label = nextLabel()
        guard let label else { return }
        draft.groups.append(ProbabilityGroup(label: label, name: "分组 \(label)"))
    }

    private func removeGroup(_ group: ProbabilityGroup) {
        guard draft.groups.count > 1 else { return }
        draft.groups.removeAll { $0.id == group.id }
        normalizeGroupLabels()
    }

    private func nextLabel() -> String? {
        let used = Set(draft.groups.map { $0.label })
        for index in 0..<30 {
            guard let label = labelForIndex(index) else { continue }
            if !used.contains(label) { return label }
        }
        return nil
    }

    private func labelForIndex(_ index: Int) -> String? {
        if index < 0 || index >= 30 { return nil }
        if index < 26 {
            guard let scalar = UnicodeScalar(65 + index) else { return nil }
            return String(Character(scalar))
        }
        guard let suffix = UnicodeScalar(65 + (index - 26)) else { return nil }
        return "A" + String(Character(suffix))
    }

    private func normalizeGroupLabels() {
        var mapping: [String: String] = [:]
        for index in draft.groups.indices {
            guard let newLabel = labelForIndex(index) else { continue }
            let oldLabel = draft.groups[index].label
            if oldLabel != newLabel {
                mapping[oldLabel.lowercased()] = newLabel.lowercased()
                draft.groups[index].label = newLabel
            }
        }
        if !mapping.isEmpty {
            draft.condition = remapConditionVariables(draft.condition, mapping: mapping)
        }
    }

    private func remapConditionVariables(_ condition: String, mapping: [String: String]) -> String {
        guard !mapping.isEmpty else { return condition }
        let pattern = "\\b[A-Za-z]+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return condition
        }
        let nsCondition = condition as NSString
        let matches = regex.matches(in: condition, range: NSRange(location: 0, length: nsCondition.length))
        if matches.isEmpty { return condition }

        var result = ""
        var lastIndex = 0
        for match in matches {
            let range = match.range
            if range.location > lastIndex {
                result += nsCondition.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex))
            }
            let token = nsCondition.substring(with: range)
            let replacement = mapping[token.lowercased()] ?? token
            result += replacement
            lastIndex = range.location + range.length
        }
        if lastIndex < nsCondition.length {
            result += nsCondition.substring(from: lastIndex)
        }
        return result
    }

    private func countForGroup(_ group: ProbabilityGroup) -> Int {
        let counts = mainDeckCardCounts()
        let map = counts.reduce(into: [Int: Int]()) { $0[$1.cardId] = $1.count }
        return group.cardIds.reduce(0) { $0 + (map[$1] ?? 0) }
    }

    private func usedCardIds(excluding groupId: UUID) -> Set<Int> {
        draft.groups
            .filter { $0.id != groupId }
            .flatMap { $0.cardIds }
            .reduce(into: Set<Int>()) { $0.insert($1) }
    }

    private func mainDeckCardCounts() -> [DeckCardCount] {
        groupCardCounts(deck.mainDeckCards)
    }

    private func groupCardCounts(_ items: [DeckCardItem]) -> [DeckCardCount] {
        let grouped = Dictionary(grouping: items, by: { $0.cardId })
        return grouped.map { DeckCardCount(cardId: $0.key, count: $0.value.count) }
            .sorted { $0.cardId < $1.cardId }
    }

    private func cardName(_ cardId: Int) -> String {
        if let card = CardRepository.shared.getCard(byId: cardId) {
            return card.displayName
        }
        return "#\(cardId)"
    }
}

private struct DeckCardCount: Identifiable {
    let cardId: Int
    let count: Int
    var id: Int { cardId }
}

/// 条件详情 Sheet
private struct ConditionDetailSheet: View {
    let condition: String
    let groups: [ProbabilityGroup]
    let previewResult: ProbabilityDisplayResult?
    let isCalculating: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    private var tokens: [String] {
        tokenize(condition)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 条件表达式区域
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("条件表达式")
                                .font(.headline)
                        }
                        
                        Text(condition.isEmpty ? "（空）" : condition)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 表达式拆解区域（放在条件表达式下面）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("表达式拆解")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(splitByTopLevelOr()) { line in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .center, spacing: 8) {
                                        ForEach(line.items) { item in
                                            switch item.kind {
                                            case .group(let group):
                                                expressionGroupView(group: group)
                                            case .text(let text):
                                                Text(text)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                    .background(Color.gray.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 即时概率区域
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            Text("即时概率")
                                .font(.headline)
                        }
                        
                        if isCalculating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("计算中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if let error = previewResult?.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if let base = previewResult?.base {
                            HStack {
                                Text("主卡组：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatProbability(base.probability))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(base.probability >= 0.5 ? .green : .orange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.bar.xaxis")
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("未计算")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // 分组含义区域
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                            Text("分组含义")
                                .font(.headline)
                        }
                        
                        ForEach(groups.indices, id: \.self) { index in
                            let group = groups[index]
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Text(group.label)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    Text(group.name.isEmpty ? "未命名分组" : group.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(group.cardIds.prefix(12), id: \.self) { cardId in
                                            cardThumbnail(cardId)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("条件详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func groupForToken(_ token: String) -> ProbabilityGroup? {
        guard let index = varToIndex(token), index < groups.count else { return nil }
        return groups[index]
    }

    private func varToIndex(_ varName: String) -> Int? {
        let name = varName.lowercased()
        if name.count == 1, let ascii = name.unicodeScalars.first?.value {
            let index = Int(ascii) - 97
            if index >= 0 && index < 26 { return index }
        }
        if name.count == 2, name.hasPrefix("a"), let second = name.unicodeScalars.last?.value {
            let index = 26 + Int(second) - 97
            if index >= 26 && index < 30 { return index }
        }
        return nil
    }

    private func tokenize(_ expression: String) -> [String] {
        let pattern = "\\s*([A-Za-z]+|\\d+|>=|<=|==|!=|&&|\\|\\||[-+*/()<>])\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [expression]
        }
        let nsExpression = expression as NSString
        let matches = regex.matches(in: expression, range: NSRange(location: 0, length: nsExpression.length))
        return matches.compactMap { match in
            let range = match.range(at: 1)
            return range.location != NSNotFound ? nsExpression.substring(with: range) : nil
        }
    }

    private struct DisplayItem: Identifiable {
        enum Kind {
            case group(ProbabilityGroup)
            case text(String)
        }
        let id = UUID()
        let kind: Kind
    }

    private struct DisplayLine: Identifiable {
        let id = UUID()
        let items: [DisplayItem]
    }

    private func buildDisplayItems() -> [DisplayItem] {
        let rawTokens = tokenize(condition)
        var items: [DisplayItem] = []
        var index = 0
        while index < rawTokens.count {
            let token = rawTokens[index]

            if let group = groupForToken(token) {
                items.append(DisplayItem(kind: .group(group)))
                index += 1
                continue
            }

            if let word = logicalWord(for: token) {
                items.append(DisplayItem(kind: .text(word)))
                index += 1
                continue
            }

            if isComparisonOperator(token), index + 1 < rawTokens.count, isNumber(rawTokens[index + 1]) {
                let number = rawTokens[index + 1]
                items.append(DisplayItem(kind: .text(comparisonWord(op: token, number: number))))
                index += 2
                continue
            }

            if let word = arithmeticWord(for: token) {
                items.append(DisplayItem(kind: .text(word)))
                index += 1
                continue
            }

            if token == "(" {
                items.append(DisplayItem(kind: .text("（")))
                index += 1
                continue
            }
            if token == ")" {
                items.append(DisplayItem(kind: .text("）")))
                index += 1
                continue
            }

            items.append(DisplayItem(kind: .text(token)))
            index += 1
        }
        return items
    }

    private func splitByTopLevelOr() -> [DisplayLine] {
        let items = buildDisplayItems()
        var lines: [DisplayLine] = []
        var current: [DisplayItem] = []
        var depth = 0

        for item in items {
            switch item.kind {
            case .text(let text):
                if text == "（" { depth += 1 }
                if text == "）" { depth = max(0, depth - 1) }
                if text == "或" && depth == 0 {
                    if !current.isEmpty {
                        lines.append(DisplayLine(items: current))
                        current = []
                    }
                    continue
                }
            case .group:
                break
            }
            current.append(item)
        }

        if !current.isEmpty {
            lines.append(DisplayLine(items: current))
        }
        return lines
    }

    private func logicalWord(for token: String) -> String? {
        switch token {
        case "&&":
            return "且"
        case "||":
            return "或"
        default:
            return nil
        }
    }

    private func arithmeticWord(for token: String) -> String? {
        switch token {
        case "+":
            return "加"
        case "-":
            return "减"
        case "*":
            return "乘"
        case "/":
            return "除"
        default:
            return nil
        }
    }

    private func comparisonWord(op: String, number: String) -> String {
        let value = Int(number) ?? 0
        switch op {
        case ">":
            return value == 0 ? "至少1张" : "多于\(value)张"
        case ">=":
            return value <= 0 ? "至少0张" : "至少\(value)张"
        case "<":
            return value <= 1 ? "没有" : "少于\(value)张"
        case "<=":
            return value == 0 ? "没有" : "至多\(value)张"
        case "==":
            return value == 0 ? "没有" : "等于\(value)张"
        case "!=":
            return value == 0 ? "至少1张" : "不等于\(value)张"
        default:
            return "\(op)\(number)"
        }
    }

    private func isComparisonOperator(_ token: String) -> Bool {
        [">", "<", ">=", "<=", "==", "!="].contains(token)
    }

    private func isNumber(_ token: String) -> Bool {
        Int(token) != nil
    }

    /// 表达式拆解中的分组视图，根据卡片数量动态展示
    /// - 1-4张：单行展示
    /// - 5-8张：双行展示（每行4张）
    /// - 超过8张：显示前7张 + "+N"标记
    @ViewBuilder
    private func expressionGroupView(group: ProbabilityGroup) -> some View {
        let cardCount = group.cardIds.count
        let maxPerRow = 4
        let maxTotal = 8
        
        VStack(spacing: 4) {
            // 分组标签
            Text(group.label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            // 卡片展示
            if cardCount <= maxPerRow {
                // 1-4张：单行展示
                HStack(spacing: 3) {
                    ForEach(group.cardIds, id: \.self) { cardId in
                        cardThumbnail(cardId, size: .thumb)
                    }
                }
            } else if cardCount <= maxTotal {
                // 5-8张：双行展示
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(Array(group.cardIds.prefix(maxPerRow)), id: \.self) { cardId in
                            cardThumbnail(cardId, size: .thumb)
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(Array(group.cardIds.dropFirst(maxPerRow).prefix(maxPerRow)), id: \.self) { cardId in
                            cardThumbnail(cardId, size: .thumb)
                        }
                    }
                }
            } else {
                // 超过8张：显示前7张 + "+N"标记
                let remaining = cardCount - 7
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(Array(group.cardIds.prefix(maxPerRow)), id: \.self) { cardId in
                            cardThumbnail(cardId, size: .thumb)
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(Array(group.cardIds.dropFirst(maxPerRow).prefix(3)), id: \.self) { cardId in
                            cardThumbnail(cardId, size: .thumb)
                        }
                        // +N 标记
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 40)
                            Text("+\(remaining)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func cardThumbnail(_ cardId: Int, size: CardImageSize = .thumb2) -> some View {
        if let url = settings.cardImageLanguage.getImageURL(for: cardId, size: size) {
            CachedAsyncImage(url: url, cacheKey: "cond-detail-\(cardId)-\(size)") { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: size == .thumb ? 28 : 36, height: size == .thumb ? 40 : 52)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: size == .thumb ? 28 : 36, height: size == .thumb ? 40 : 52)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

private struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.immediately)
        } else {
            content
        }
    }
}

private struct DoneTextEditor: UIViewRepresentable {
    @Binding var text: String
    let onBeginEditing: () -> Void
    let onDone: () -> Void

    init(
        text: Binding<String>,
        onBeginEditing: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {}
    ) {
        _text = text
        self.onBeginEditing = onBeginEditing
        self.onDone = onDone
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.returnKeyType = .done
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onBeginEditing: onBeginEditing, onDone: onDone)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var text: Binding<String>
        private let onBeginEditing: () -> Void
        private let onDone: () -> Void

        init(
            text: Binding<String>,
            onBeginEditing: @escaping () -> Void,
            onDone: @escaping () -> Void
        ) {
            self.text = text
            self.onBeginEditing = onBeginEditing
            self.onDone = onDone
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            onBeginEditing()
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text ?? ""
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            if replacement == "\n" {
                textView.resignFirstResponder()
                onDone()
                return false
            }
            return true
        }
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// 卡片选择 Sheet
private struct CardPickerSheet: View {
    let title: String
    let cards: [DeckCardCount]
    @Binding var selectedCardIds: Set<Int>
    let disabledCardIds: Set<Int>
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            List {
                ForEach(cards) { item in
                    Button {
                        toggle(item.cardId)
                    } label: {
                        HStack {
                            cardThumbnail(item.cardId)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cardName(item.cardId))
                                Text("数量：\(item.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedCardIds.contains(item.cardId) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(disabledCardIds.contains(item.cardId))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggle(_ cardId: Int) {
        if selectedCardIds.contains(cardId) {
            selectedCardIds.remove(cardId)
        } else {
            selectedCardIds.insert(cardId)
        }
    }

    @ViewBuilder
    private func cardThumbnail(_ cardId: Int) -> some View {
        if let url = settings.cardImageLanguage.getImageURL(for: cardId, size: .thumb) {
            CachedAsyncImage(url: url, cacheKey: "prob-picker-\(cardId)") { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 36, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 36, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func cardName(_ cardId: Int) -> String {
        if let card = CardRepository.shared.getCard(byId: cardId) {
            return settings.getDisplayName(for: card)
        }
        return "#\(cardId)"
    }
}

private func formatProbability(_ value: Double) -> String {
    String(format: "%.2f%%", value)
}
