//
//  DeckBattleView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/14.
//

import SwiftUI

/// 对战模拟主视图 — 10次对决模式
struct DeckBattleView: View {
    @StateObject private var viewModel: DeckBattleViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showHistory = false
    @State private var editingSide: DeckBattleViewModel.BattleSide?
    @State private var showSaveConfirm = false
    @State private var noteText = ""
    @State private var toastMessage: String?

    init(session: BattleSession, allDecks: [Deck]) {
        let deckA = allDecks.first(where: { $0.id == session.deckAId }) ?? Deck(name: session.deckAName)
        let deckB = allDecks.first(where: { $0.id == session.deckBId }) ?? Deck(name: session.deckBName)
        _viewModel = StateObject(wrappedValue: DeckBattleViewModel(deckA: deckA, deckB: deckB, existingSession: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 对战主区域
            ScrollView {
                VStack(spacing: 12) {
                    // side 状态指示 + 当前统计
                    headerSection

                    // 10轮对决
                    if viewModel.rounds.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("点击下方按钮开始模拟")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(Array(viewModel.rounds.enumerated()), id: \.element.id) { index, round in
                            roundCard(round: round, index: index)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }

            Divider()

            // 底部操作栏
            bottomActionBar
                .padding()
                .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("对战模拟")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            BattleHistoryView(viewModel: viewModel)
        }
        .sheet(item: $editingSide) { side in
            BattleSideEditorView(
                viewModel: viewModel,
                side: side,
                isPresented: Binding(
                    get: { editingSide != nil },
                    set: { if !$0 { editingSide = nil } }
                )
            )
        }
        .alert("保存记录", isPresented: $showSaveConfirm) {
            TextField("备注（可选）", text: $noteText)
            Button("保存") {
                if viewModel.saveRecord(note: noteText) {
                    noteText = ""
                    showToast("已保存 \(viewModel.currentMarkedCount) 局记录")
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已标记 \(viewModel.currentMarkedCount) / \(viewModel.rounds.count) 局结果")
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "操作失败")
        }
        .overlay(
            VStack {
                Spacer()
                if let message = toastMessage {
                    ToastView(message: message)
                        .padding(.bottom, 50)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: toastMessage)
                }
            }
        )
        .task {
            if viewModel.rounds.isEmpty {
                await viewModel.drawTenRounds()
            }
        }
    }

    // MARK: - 顶部信息

    private var headerSection: some View {
        VStack(spacing: 8) {
            if viewModel.isSided {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundColor(.orange)
                    Text("已更换副卡组")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }

            // 当前统计
            if viewModel.currentMarkedCount > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text(viewModel.currentDeckA.name)
                            .font(.caption)
                            .lineLimit(1)
                        Text("\(viewModel.currentAWins)胜")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                    }

                    Text(":")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("\(viewModel.currentBWins)胜")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                        Text(viewModel.currentDeckB.name)
                            .font(.caption)
                            .lineLimit(1)
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 单轮对决卡片

    @ViewBuilder
    private func roundCard(round: BattleRound, index: Int) -> some View {
        VStack(spacing: 8) {
            // 轮次标题 + 胜者标记
            HStack {
                Text("第 \(index + 1) 局")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()

                // 胜者标记胶囊
                ForEach(round.winners) { winner in
                    Text(winner.isAWinner ? "\(viewModel.currentDeckA.name) \(winner.winnerLabel)" : "\(viewModel.currentDeckB.name) \(winner.winnerLabel)")
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(winner.isAWinner ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(winner.isAWinner ? .blue : .red)
                        .clipShape(Capsule())
                }

                if round.winners.isEmpty {
                    Text("未标记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // A方手牌
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                    Text(viewModel.currentDeckA.name)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 14)

                compactCardGrid(cardIds: round.deckAHand, roundIndex: index, side: "A")
                    .padding(.horizontal, 14)
            }

            // B方手牌
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text(viewModel.currentDeckB.name)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 14)

                compactCardGrid(cardIds: round.deckBHand, roundIndex: index, side: "B")
                    .padding(.horizontal, 14)
            }

            // 结果标记按钮
            resultButtons(roundIndex: index, currentWinners: round.winners)
                .padding(.horizontal, 14)

            // 单局备注
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("备注", text: Binding(
                    get: { viewModel.rounds[index].note },
                    set: { viewModel.updateRoundNote(roundIndex: index, note: $0) }
                ))
                .font(.caption)
                .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 卡图网格

    @ViewBuilder
    private func compactCardGrid(cardIds: [Int], roundIndex: Int, side: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
            ForEach(Array(cardIds.enumerated()), id: \.offset) { idx, cardId in
                CachedAsyncImage(
                    url: settings.cardImageLanguage.getImageURL(for: cardId, size: .half),
                    cacheKey: "battle-\(viewModel.drawSessionId)-\(roundIndex)-\(side)-\(idx)-\(cardId)"
                ) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(0.69, contentMode: .fit)
                        .overlay(ProgressView())
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    // MARK: - 结果标记按钮（多选 + 颜色区分）

    @ViewBuilder
    private func resultButtons(roundIndex: Int, currentWinners: [BattleWinner]) -> some View {
        VStack(spacing: 6) {
            // A方按钮行（蓝色系）
            HStack(spacing: 6) {
                resultButton(
                    label: "先攻胜",
                    icon: "1.circle.fill",
                    winner: .deckAFirst,
                    isSelected: currentWinners.contains(.deckAFirst),
                    baseColor: .blue,
                    roundIndex: roundIndex
                )
                resultButton(
                    label: "后攻胜",
                    icon: "2.circle.fill",
                    winner: .deckASecond,
                    isSelected: currentWinners.contains(.deckASecond),
                    baseColor: .blue,
                    roundIndex: roundIndex
                )
            }

            // B方按钮行（红色系）
            HStack(spacing: 6) {
                resultButton(
                    label: "先攻胜",
                    icon: "1.circle.fill",
                    winner: .deckBFirst,
                    isSelected: currentWinners.contains(.deckBFirst),
                    baseColor: .red,
                    roundIndex: roundIndex
                )
                resultButton(
                    label: "后攻胜",
                    icon: "2.circle.fill",
                    winner: .deckBSecond,
                    isSelected: currentWinners.contains(.deckBSecond),
                    baseColor: .red,
                    roundIndex: roundIndex
                )
            }
        }
    }

    @ViewBuilder
    private func resultButton(label: String, icon: String, winner: BattleWinner, isSelected: Bool, baseColor: Color, roundIndex: Int) -> some View {
        let deckName = winner.isAWinner ? viewModel.currentDeckA.name : viewModel.currentDeckB.name
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.toggleRoundWinner(roundIndex: roundIndex, winner: winner)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(deckName) \(label)")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? baseColor : Color.clear)
            .foregroundColor(isSelected ? .white : baseColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(baseColor, lineWidth: isSelected ? 0 : 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - 底部操作栏

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            // 更换副卡组按钮
            Menu {
                Button {
                    editingSide = .a
                } label: {
                    Label("\(viewModel.currentDeckA.name)", systemImage: "a.circle")
                }
                Button {
                    editingSide = .b
                } label: {
                    Label("\(viewModel.currentDeckB.name)", systemImage: "b.circle")
                }
                if viewModel.isSided {
                    Divider()
                    Button(role: .destructive) {
                        viewModel.resetToMainDeck()
                        Task { await viewModel.drawTenRounds() }
                    } label: {
                        Label("还原主卡组", systemImage: "arrow.uturn.backward")
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal, Color.teal.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
            }

            // 保存记录按钮
            Button {
                showSaveConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("保存 (\(viewModel.currentMarkedCount)/\(viewModel.rounds.count))")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.currentMarkedCount == 0)
            .opacity(viewModel.currentMarkedCount == 0 ? 0.5 : 1.0)

            // 重新洗牌按钮
            Button {
                Task { await viewModel.drawTenRounds() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "shuffle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

// MARK: - 历史记录视图

struct BattleHistoryView: View {
    @ObservedObject var viewModel: DeckBattleViewModel
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab 切换
                Picker("", selection: $selectedTab) {
                    Text("主卡组 (\(viewModel.mainRecords.count))").tag(0)
                    Text("副卡组 (\(viewModel.sidedRecords.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // 总体胜率统计
                let records = selectedTab == 0 ? viewModel.mainRecords : viewModel.sidedRecords
                if !records.isEmpty {
                    winRateSection(records: records)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // 记录列表
                if records.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无记录")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(records) { record in
                            BattleRecordRow(
                                record: record,
                                deckAName: viewModel.session.deckAName,
                                deckBName: viewModel.session.deckBName
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteRecord(record)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - 胜率统计

    @ViewBuilder
    private func winRateSection(records: [BattleRecord]) -> some View {
        let allRounds = records.flatMap(\.rounds).flatMap(\.winners)
        let total = allRounds.count
        if total > 0 {

        let aWins = allRounds.filter(\.isAWinner).count
        let bWins = total - aWins
        let firstWins = allRounds.filter(\.isFirstPlayerWin).count
        let secondWins = total - firstWins

        VStack(spacing: 8) {
            // A vs B 胜率
            HStack(spacing: 0) {
                let aPercent = Double(aWins) / Double(total)
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: max(CGFloat(aPercent) * (UIScreen.main.bounds.width - 32), 0))
                Rectangle()
                    .fill(Color.red.opacity(0.7))
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack {
                Text("\(viewModel.session.deckAName): \(aWins)胜")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Text("\(total)局")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.session.deckBName): \(bWins)胜")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // 先攻/后攻胜率
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "1.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("先攻胜率: \(percentage(firstWins, total))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "2.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("后攻胜率: \(percentage(secondWins, total))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func percentage(_ count: Int, _ total: Int) -> String {
        guard total > 0 else { return "0%" }
        let p = Double(count) / Double(total) * 100
        return String(format: "%.0f%%", p)
    }
}

/// 历史记录行 — 详细展示每轮手牌
struct BattleRecordRow: View {
    let record: BattleRecord
    let deckAName: String
    let deckBName: String
    @ObservedObject private var settings = AppSettings.shared
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行：统计 + 时间 + 展开按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetail.toggle()
                }
            } label: {
                HStack {
                    Text("\(record.aWinCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                    Text(":")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(record.bWinCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)

                    Text("先攻\(record.firstPlayerWinCount)胜 后攻\(record.secondPlayerWinCount)胜")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    Spacer()

                    Text(formatDate(record.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // 每轮结果小方块（始终显示）
            HStack(spacing: 3) {
                ForEach(record.rounds) { round in
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(roundColor(round).opacity(0.2))
                            .frame(width: 24, height: 20)
                        if !round.winners.isEmpty {
                            let hasA = round.winners.contains(where: \.isAWinner)
                            Text(hasA ? "A" : "B")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(roundColor(round))
                        } else {
                            Text("-")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 副卡组信息
            if record.isSided {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("已更换副卡组")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // 备注
            if !record.note.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(record.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 展开：每轮详细手牌
            if showDetail {
                VStack(spacing: 10) {
                    ForEach(record.rounds) { round in
                        historyRoundDetail(round: round)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func historyRoundDetail(round: BattleRound) -> some View {
        VStack(spacing: 6) {
            // 轮次标题 + 胜者
            HStack {
                Text("第 \(round.index + 1) 局")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()

                ForEach(round.winners) { winner in
                    Text(winner.isAWinner ? "\(deckAName) \(winner.winnerLabel)" : "\(deckBName) \(winner.winnerLabel)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(winner.isAWinner ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(winner.isAWinner ? .blue : .red)
                        .clipShape(Capsule())
                }

                if round.winners.isEmpty {
                    Text("未标记")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // A方手牌
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 5, height: 5)
                    Text(deckAName)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                historyCardGrid(cardIds: round.deckAHand)
            }

            // B方手牌
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 5, height: 5)
                    Text(deckBName)
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                historyCardGrid(cardIds: round.deckBHand)
            }

            // 单局备注
            if !round.note.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(round.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if round.index < record.rounds.count - 1 {
                Divider()
            }
        }
    }

    @ViewBuilder
    private func historyCardGrid(cardIds: [Int]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 5), spacing: 3) {
            ForEach(Array(cardIds.enumerated()), id: \.offset) { _, cardId in
                CachedAsyncImage(
                    url: settings.cardImageLanguage.getImageURL(for: cardId, size: .half),
                    cacheKey: "history-\(cardId)"
                ) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(0.69, contentMode: .fit)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }

    private func roundColor(_ round: BattleRound) -> Color {
        guard let first = round.winners.first else { return .secondary }
        return first.isAWinner ? .blue : .red
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 副卡组更换编辑器

struct BattleSideEditorView: View {
    @ObservedObject var viewModel: DeckBattleViewModel
    let side: DeckBattleViewModel.BattleSide
    @Binding var isPresented: Bool
    @ObservedObject private var settings = AppSettings.shared

    @State private var swapOutMain: [SideboardCardChange] = []
    @State private var swapInMain: [SideboardCardChange] = []
    @State private var swapOutExtra: [SideboardCardChange] = []
    @State private var swapInExtra: [SideboardCardChange] = []
    @State private var selectedPlayOrder: SideboardPlayOrder = .first
    @State private var toastMessage: String?

    private var currentDeck: Deck {
        side == .a ? viewModel.originalDeckA : viewModel.originalDeckB
    }

    private var availableStrategies: [SideboardStrategy] {
        currentDeck.sideboardStrategies
    }

    private var hasExtraSide: Bool {
        currentDeck.sideDeckCards.contains { cardId in
            if let card = CardRepository.shared.getCard(byId: cardId.cardId),
               let type = card.data?.type {
                let cardType = CardType(rawValue: type)
                return cardType.contains(.fusion) || cardType.contains(.synchro) || cardType.contains(.xyz) || cardType.contains(.link)
            }
            return false
        }
    }

    var body: some View {
        NavigationView {
            List {
                if !availableStrategies.isEmpty {
                    Section(header: Text("应用副卡组策略")) {
                        ForEach(availableStrategies) { strategy in
                            DisclosureGroup {
                                // 先攻策略
                                Button {
                                    applyStrategy(strategy, order: .first)
                                } label: {
                                    strategyOrderRow(strategy: strategy, order: .first)
                                }

                                // 后攻策略
                                Button {
                                    applyStrategy(strategy, order: .second)
                                } label: {
                                    strategyOrderRow(strategy: strategy, order: .second)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("VS")
                                        .font(.caption2)
                                        .fontWeight(.black)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(LinearGradient(
                                                    colors: [.red, .orange],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ))
                                        )
                                    Text(strategy.vsDeckName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("从主卡组移出")) {
                    let mainCards = groupCards(currentDeck.mainDeckCards)
                    if mainCards.isEmpty {
                        Text("主卡组为空").font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(mainCards, id: \.cardId) { group in
                            sideCardRow(cardId: group.cardId, availableCount: group.count, changes: $swapOutMain, label: "移出")
                        }
                    }
                }

                Section(header: Text("从副卡组换入主卡组")) {
                    let mainSideCards = hasExtraSide
                        ? groupCards(currentDeck.sideDeckCards).filter { group in
                            if let card = CardRepository.shared.getCard(byId: group.cardId),
                               let type = card.data?.type {
                                let cardType = CardType(rawValue: type)
                                return !(cardType.contains(.fusion) || cardType.contains(.synchro) || cardType.contains(.xyz) || cardType.contains(.link))
                            }
                            return true
                        }
                        : groupCards(currentDeck.sideDeckCards)
                    if mainSideCards.isEmpty {
                        Text("副卡组为空").font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(mainSideCards, id: \.cardId) { group in
                            sideCardRow(cardId: group.cardId, availableCount: group.count, changes: $swapInMain, label: "换入")
                        }
                    }
                }

                if !currentDeck.extraDeckCards.isEmpty || hasExtraSide {
                    if !currentDeck.extraDeckCards.isEmpty {
                        Section(header: Text("从额外卡组移出")) {
                            let extraCards = groupCards(currentDeck.extraDeckCards)
                            ForEach(extraCards, id: \.cardId) { group in
                                sideCardRow(cardId: group.cardId, availableCount: group.count, changes: $swapOutExtra, label: "移出")
                            }
                        }
                    }

                    if hasExtraSide {
                        Section(header: Text("从副卡组换入额外卡组")) {
                            let extraSideCards = groupCards(currentDeck.sideDeckCards).filter { group in
                                if let card = CardRepository.shared.getCard(byId: group.cardId),
                                   let type = card.data?.type {
                                    let cardType = CardType(rawValue: type)
                                    return cardType.contains(.fusion) || cardType.contains(.synchro) || cardType.contains(.xyz) || cardType.contains(.link)
                                }
                                return false
                            }
                            if extraSideCards.isEmpty {
                                Text("副卡组中无额外卡片").font(.caption).foregroundColor(.secondary)
                            } else {
                                ForEach(extraSideCards, id: \.cardId) { group in
                                    sideCardRow(cardId: group.cardId, availableCount: group.count, changes: $swapInExtra, label: "换入")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("更换副卡组 - \(currentDeck.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        applySideChanges()
                        isPresented = false
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                if let message = toastMessage {
                    ToastView(message: message)
                        .padding(.bottom, 50)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: toastMessage)
                }
            }
        )
    }

    @ViewBuilder
    private func sideCardRow(cardId: Int, availableCount: Int, changes: Binding<[SideboardCardChange]>, label: String) -> some View {
        let currentCount = changes.wrappedValue.first(where: { $0.cardId == cardId })?.count ?? 0

        HStack(spacing: 10) {
            CachedAsyncImage(
                url: settings.cardImageLanguage.getImageURL(for: cardId, size: .thumb2),
                cacheKey: "side-\(cardId)"
            ) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.2)).aspectRatio(0.69, contentMode: .fit)
            }
            .frame(width: 36)
            .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                if let card = CardRepository.shared.getCard(byId: cardId) {
                    Text(card.displayName).font(.caption).lineLimit(1)
                } else {
                    Text("ID: \(cardId)").font(.caption).foregroundColor(.secondary)
                }
                Text("×\(availableCount)").font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    updateCount(cardId: cardId, changes: changes, delta: -1)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(currentCount > 0 ? .red : .secondary.opacity(0.3))
                }
                .disabled(currentCount <= 0)

                Text("\(currentCount)")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 24)

                Button {
                    updateCount(cardId: cardId, changes: changes, delta: 1)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(currentCount < availableCount ? .blue : .secondary.opacity(0.3))
                }
                .disabled(currentCount >= availableCount)
            }
        }
        .padding(.vertical, 2)
    }

    private func updateCount(cardId: Int, changes: Binding<[SideboardCardChange]>, delta: Int) {
        if let index = changes.wrappedValue.firstIndex(where: { $0.cardId == cardId }) {
            let newCount = changes.wrappedValue[index].count + delta
            if newCount <= 0 {
                changes.wrappedValue.remove(at: index)
            } else {
                changes.wrappedValue[index].count = newCount
            }
        } else if delta > 0 {
            changes.wrappedValue.append(SideboardCardChange(cardId: cardId, count: 1))
        }
    }

    private func groupCards(_ items: [DeckCardItem]) -> [(cardId: Int, count: Int)] {
        Dictionary(grouping: items, by: { $0.cardId })
            .map { (cardId: $0.key, count: $0.value.count) }
            .sorted { $0.cardId < $1.cardId }
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }

    @ViewBuilder
    private func strategyOrderRow(strategy: SideboardStrategy, order: SideboardPlayOrder) -> some View {
        let swapSet = order == .first ? strategy.first : strategy.second
        let accentColor: Color = order == .first ? .blue : .purple
        let totalOut = swapSet.swapOutMain.reduce(0) { $0 + $1.count } + swapSet.swapOutExtra.reduce(0) { $0 + $1.count }
        let totalIn = swapSet.swapInMain.reduce(0) { $0 + $1.count } + swapSet.swapInExtra.reduce(0) { $0 + $1.count }
        let hasExtra = !swapSet.swapOutExtra.isEmpty || !swapSet.swapInExtra.isEmpty

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 3, height: 12)
                    Text(order.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(accentColor)
                }

                if totalOut == 0 && totalIn == 0 {
                    Text("未设置")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Label("出\(totalOut)", systemImage: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Label("入\(totalIn)", systemImage: "arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        if hasExtra {
                            Text("含额外")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "arrow.right.circle")
                .foregroundColor(totalOut == 0 && totalIn == 0 ? .secondary.opacity(0.3) : accentColor)
        }
        .padding(.vertical, 2)
    }

    private func applyStrategy(_ strategy: SideboardStrategy, order: SideboardPlayOrder) {
        let swapSet = order == .first ? strategy.first : strategy.second
        swapOutMain = swapSet.swapOutMain
        swapInMain = swapSet.swapInMain
        swapOutExtra = swapSet.swapOutExtra
        swapInExtra = swapSet.swapInExtra
        selectedPlayOrder = order
        showToast("已应用「\(strategy.vsDeckName)」\(order.rawValue)策略")
    }

    private func applySideChanges() {
        let swapSet = SideboardSwapSet(
            swapOutMain: swapOutMain,
            swapInMain: swapInMain,
            swapOutExtra: swapOutExtra,
            swapInExtra: swapInExtra
        )
        viewModel.applySideboardStrategy(swapSet, for: side)
    }
}

// MARK: - 卡组选择视图

struct DeckBattleSetupView: View {
    let decks: [Deck]
    let onConfirm: (Deck, Deck) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDeckA: Deck?
    @State private var selectedDeckB: Deck?
    @State private var step = 1

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    stepIndicator(number: 1, title: "选择卡组A", isActive: step == 1, isDone: selectedDeckA != nil)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    stepIndicator(number: 2, title: "选择卡组B", isActive: step == 2, isDone: selectedDeckB != nil)
                }
                .padding()

                if let deckA = selectedDeckA, step == 2 {
                    HStack(spacing: 8) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("A: \(deckA.name)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Button("重选") {
                            selectedDeckA = nil
                            selectedDeckB = nil
                            step = 1
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                List {
                    ForEach(decks) { deck in
                        Button {
                            selectDeck(deck)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deck.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    HStack(spacing: 12) {
                                        Label("\(deck.mainDeckCount)", systemImage: "rectangle.stack")
                                            .font(.caption).foregroundColor(.blue)
                                        Label("\(deck.extraDeckCount)", systemImage: "square.stack.3d.up")
                                            .font(.caption).foregroundColor(.purple)
                                        Label("\(deck.sideDeckCount)", systemImage: "square.stack")
                                            .font(.caption).foregroundColor(.orange)
                                    }
                                }
                                Spacer()

                                if selectedDeckA?.id == deck.id && step == 2 {
                                    Text("A")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("新建对战模拟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private func stepIndicator(number: Int, title: String, isActive: Bool, isDone: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isActive ? Color.blue : Color.secondary.opacity(0.3)))
                    .frame(width: 24, height: 24)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(isActive ? .white : .secondary)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }

    private func selectDeck(_ deck: Deck) {
        if step == 1 {
            selectedDeckA = deck
            step = 2
        } else {
            selectedDeckB = deck
            dismiss()
            onConfirm(selectedDeckA!, deck)
        }
    }
}
