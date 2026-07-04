//
//  DuelCalculatorView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/22.
//

import SwiftUI

// MARK: - 科技感配色

private enum DuelTheme {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.08)
    static let panelBg = Color.white.opacity(0.05)
    static let cyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.0, blue: 0.6)
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.5)
    static let neonRed = Color(red: 1.0, green: 0.15, blue: 0.25)
    static let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let neonBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let dimText = Color.white.opacity(0.4)
    static let bodyText = Color.white.opacity(0.85)
}

/// 决斗计算器主视图 — 横屏双键盘布局（科技感）
struct DuelCalculatorView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = DuelCalculatorViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var inputBufferA = ""
    @State private var inputBufferB = ""
    @State private var showHistory = false
    @State private var historySide: PlayerSide = .playerA
    @State private var showResetConfirm = false
    @State private var showDiceOverlay = false
    @State private var showCoinOverlay = false
    @State private var overlayDiceResult: Int = 1
    @State private var overlayCoinResult: CoinResult = .heads

    var body: some View {
        ZStack {
            DuelTheme.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                playerSide(side: .playerA, inputBuffer: $inputBufferA)
                centerColumn
                playerSide(side: .playerB, inputBuffer: $inputBufferB)
            }

            if showDiceOverlay { diceOverlay }
            if showCoinOverlay { coinOverlay }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .alert("重置决斗", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                withAnimation {
                    viewModel.resetDuel()
                    inputBufferA = ""
                    inputBufferB = ""
                }
            }
        } message: {
            Text("确定要重置决斗吗？双方 LP 和所有记录将被清空。")
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
        .sheet(isPresented: $showHistory) {
            LPHistorySheet(
                side: historySide,
                history: historySide == .playerA ? viewModel.playerAHistory : viewModel.playerBHistory
            )
        }
        .onAppear { forceLandscape() }
        .onDisappear { restorePortrait() }
        .onChange(of: scenePhase) { newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
    }

    // MARK: - 方向控制

    private func forceLandscape() {
        OrientationManager.shared.orientationLock = .landscape
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        }
    }

    private func restorePortrait() {
        OrientationManager.shared.orientationLock = .portrait
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
        // 延迟再次强制，确保 NavigationView pop 动画完成后生效
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            OrientationManager.shared.orientationLock = .portrait
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    // MARK: - 单侧玩家区域

    private func playerSide(side: PlayerSide, inputBuffer: Binding<String>) -> some View {
        let lp = viewModel.currentLP(for: side)
        let history = side == .playerA ? viewModel.playerAHistory : viewModel.playerBHistory
        let lpRatio = CGFloat(lp) / CGFloat(kInitialLP)
        let accentColor = side == .playerA ? DuelTheme.cyan : DuelTheme.magenta

        return VStack(spacing: 6) {
            // LP 信息区
            VStack(spacing: 4) {
                HStack {
                    Text(side.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor)
                        .textCase(.uppercase)
                    Spacer()
                    Button {
                        historySide = side
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                            .frame(width: 32, height: 32)
                            .foregroundColor(DuelTheme.dimText)
                    }
                    .disabled(history.isEmpty)

                    Button {
                        withAnimation { viewModel.undoLastChange(for: side) }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body)
                            .frame(width: 32, height: 32)
                            .foregroundColor(DuelTheme.dimText)
                    }
                    .disabled(history.isEmpty)
                }

                Text(formatLP(lp))
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundColor(lp == 0 ? DuelTheme.neonRed : .white)
                    .shadow(color: (lp == 0 ? DuelTheme.neonRed : accentColor).opacity(0.6), radius: 8)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // LP 霓虹进度条
                GeometryReader { geo in
                    ZStack(alignment: side == .playerA ? .leading : .trailing) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(lpBarColor(ratio: lpRatio))
                            .frame(width: max(0, geo.size.width * min(1.0, lpRatio)), height: 5)
                            .shadow(color: accentColor.opacity(0.7), radius: 4, y: 0)
                            .animation(.easeInOut(duration: 0.3), value: lp)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DuelTheme.panelBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            )

            // 输入值显示
            HStack {
                Text(inputBuffer.wrappedValue.isEmpty ? "0" : formatLP(Int(inputBuffer.wrappedValue) ?? 0))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(inputBuffer.wrappedValue.isEmpty ? DuelTheme.dimText : accentColor)
                    .shadow(color: accentColor.opacity(inputBuffer.wrappedValue.isEmpty ? 0 : 0.5), radius: 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(DuelTheme.panelBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor.opacity(0.15), lineWidth: 1)
            )

            numpadWithOps(side: side, inputBuffer: inputBuffer)
                .frame(maxHeight: .infinity)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 镜像键盘布局

    @ViewBuilder
    private func numpadWithOps(side: PlayerSide, inputBuffer: Binding<String>) -> some View {
        let numRows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["00", "0", "⌫"]
        ]

        HStack(spacing: 5) {
            if side == .playerA {
                opsColumn(side: side, inputBuffer: inputBuffer)
                numpadGrid(numRows: numRows, inputBuffer: inputBuffer)
            } else {
                numpadGrid(numRows: numRows, inputBuffer: inputBuffer)
                opsColumn(side: side, inputBuffer: inputBuffer)
            }
        }
    }

    private func numpadGrid(numRows: [[String]], inputBuffer: Binding<String>) -> some View {
        VStack(spacing: 5) {
            ForEach(numRows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleNumpadKey(key, buffer: inputBuffer)
                        } label: {
                            Text(key)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.white.opacity(0.07))
                                .foregroundColor(DuelTheme.bodyText)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private func opsColumn(side: PlayerSide, inputBuffer: Binding<String>) -> some View {
        return VStack(spacing: 5) {
            ForEach(LPChangeType.allCases) { op in
                Button {
                    applyOperation(op, side: side, buffer: inputBuffer)
                } label: {
                    Text(op.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(opColor(op).opacity(0.12))
                        .foregroundColor(opColor(op))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(opColor(op).opacity(0.25), lineWidth: 1)
                        )
                }
                .disabled(inputBuffer.wrappedValue.isEmpty && op != .set)
            }
        }
        .frame(width: 50)
    }

    // MARK: - 中间工具栏

    private var centerColumn: some View {
        VStack(spacing: 12) {
            Button {
                selectedTab = 0
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DuelTheme.dimText)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            // 计时器
            VStack(spacing: 6) {
                Text(viewModel.timerDisplay)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(DuelTheme.cyan)
                    .shadow(color: DuelTheme.cyan.opacity(0.5), radius: 4)

                HStack(spacing: 8) {
                    Button {
                        if viewModel.isTimerRunning {
                            viewModel.pauseTimer()
                        } else {
                            viewModel.startTimer()
                        }
                    } label: {
                        Image(systemName: viewModel.isTimerRunning ? "pause.fill" : "play.fill")
                            .font(.caption)
                            .foregroundColor(DuelTheme.cyan)
                            .frame(width: 28, height: 28)
                            .background(DuelTheme.cyan.opacity(0.12))
                            .clipShape(Circle())
                    }

                    Button {
                        viewModel.resetTimer()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundColor(DuelTheme.dimText)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.elapsedSeconds == 0 && !viewModel.isTimerRunning)
                }
            }

            Spacer()

            // 骰子按钮
            Button {
                rollDiceWithOverlay()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "dice.fill")
                        .font(.title2)
                        .foregroundColor(DuelTheme.neonOrange)
                    Text("骰子")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(DuelTheme.dimText)
                }
                .frame(width: 56, height: 56)
                .background(DuelTheme.neonOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DuelTheme.neonOrange.opacity(0.25), lineWidth: 1)
                )
            }
            .disabled(showDiceOverlay)

            // 硬币按钮
            Button {
                flipCoinWithOverlay()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "circle.circle.fill")
                        .font(.title2)
                        .foregroundColor(DuelTheme.neonBlue)
                    Text("硬币")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(DuelTheme.dimText)
                }
                .frame(width: 56, height: 56)
                .background(DuelTheme.neonBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DuelTheme.neonBlue.opacity(0.25), lineWidth: 1)
                )
            }
            .disabled(showCoinOverlay)

            Spacer()

            // 重置按钮
            Button {
                showResetConfirm = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DuelTheme.neonRed)
                    .frame(width: 40, height: 40)
                    .background(DuelTheme.neonRed.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(DuelTheme.neonRed.opacity(0.25), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 12)
        .frame(width: 72)
    }

    // MARK: - 骰子动画覆盖层

    private func rollDiceWithOverlay() {
        let result = Int.random(in: 1...6)
        overlayDiceResult = result
        viewModel.diceResult = result
        withAnimation(.easeInOut(duration: 0.2)) { showDiceOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) { showDiceOverlay = false }
        }
    }

    private var diceOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { withAnimation { showDiceOverlay = false } }

            VStack(spacing: 16) {
                Image(systemName: diceFaceName(overlayDiceResult))
                    .font(.system(size: 100))
                    .foregroundColor(DuelTheme.neonOrange)
                    .shadow(color: DuelTheme.neonOrange.opacity(0.8), radius: 20)
                    .rotationEffect(.degrees(showDiceOverlay ? 0 : 360))
                    .scaleEffect(showDiceOverlay ? 1.0 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showDiceOverlay)

                Text("\(overlayDiceResult)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: DuelTheme.neonOrange.opacity(0.6), radius: 8)
            }
        }
        .transition(.opacity)
    }

    private func diceFaceName(_ value: Int) -> String {
        switch value {
        case 1: return "die.face.1.fill"
        case 2: return "die.face.2.fill"
        case 3: return "die.face.3.fill"
        case 4: return "die.face.4.fill"
        case 5: return "die.face.5.fill"
        case 6: return "die.face.6.fill"
        default: return "die.face.1.fill"
        }
    }

    // MARK: - 硬币动画覆盖层

    private func flipCoinWithOverlay() {
        let result: CoinResult = Bool.random() ? .heads : .tails
        overlayCoinResult = result
        viewModel.coinResult = result
        withAnimation(.easeInOut(duration: 0.2)) { showCoinOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) { showCoinOverlay = false }
        }
    }

    private var coinOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { withAnimation { showCoinOverlay = false } }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: overlayCoinResult == .heads
                                    ? [DuelTheme.cyan, DuelTheme.neonBlue]
                                    : [DuelTheme.magenta, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: (overlayCoinResult == .heads ? DuelTheme.cyan : DuelTheme.magenta).opacity(0.8), radius: 20)

                    Text(overlayCoinResult == .heads ? "正" : "反")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                .rotation3DEffect(
                    .degrees(showCoinOverlay ? 0 : 720),
                    axis: (x: 0, y: 1, z: 0)
                )
                .scaleEffect(showCoinOverlay ? 1.0 : 0.3)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCoinOverlay)

                Text(overlayCoinResult.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: (overlayCoinResult == .heads ? DuelTheme.cyan : DuelTheme.magenta).opacity(0.6), radius: 8)
            }
        }
        .transition(.opacity)
    }

    // MARK: - 键盘 / 操作辅助

    private func handleNumpadKey(_ key: String, buffer: Binding<String>) {
        switch key {
        case "⌫":
            if !buffer.wrappedValue.isEmpty {
                buffer.wrappedValue.removeLast()
            }
        case "00":
            if !buffer.wrappedValue.isEmpty {
                buffer.wrappedValue += "00"
            }
        default:
            if buffer.wrappedValue == "0" {
                buffer.wrappedValue = key
            } else {
                buffer.wrappedValue += key
            }
        }
        if buffer.wrappedValue.count > 6 {
            buffer.wrappedValue = String(buffer.wrappedValue.prefix(6))
        }
    }

    private func applyOperation(_ op: LPChangeType, side: PlayerSide, buffer: Binding<String>) {
        let value = Int(buffer.wrappedValue) ?? 0
        guard value > 0 || op == .set else { return }
        withAnimation {
            switch op {
            case .damage: viewModel.applyDamage(value, to: side)
            case .recover: viewModel.applyRecovery(value, to: side)
            case .pay: viewModel.applyPay(value, to: side)
            case .set: viewModel.applySet(value, to: side)
            }
        }
        buffer.wrappedValue = ""
    }

    private func opColor(_ op: LPChangeType) -> Color {
        switch op {
        case .damage: return DuelTheme.neonRed
        case .recover: return DuelTheme.neonGreen
        case .pay: return DuelTheme.neonOrange
        case .set: return DuelTheme.neonBlue
        }
    }

    private func lpBarColor(ratio: CGFloat) -> Color {
        if ratio > 0.5 { return DuelTheme.neonGreen }
        if ratio > 0.25 { return DuelTheme.neonOrange }
        return DuelTheme.neonRed
    }

    private func formatLP(_ lp: Int) -> String {
        return "\(lp)"
    }
}

// MARK: - LP 历史 Sheet（科技感）

struct LPHistorySheet: View {
    let side: PlayerSide
    let history: [LPChange]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if history.isEmpty {
                    Text("暂无操作记录")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(DuelTheme.dimText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DuelTheme.bg)
                } else {
                    List(history.reversed()) { change in
                        HStack {
                            Text(change.type.rawValue)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(historyColor(change.type))

                            Spacer()

                            Text(changeValueText(change))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(DuelTheme.dimText)

                            Text("→ \(change.resultLP)")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(DuelTheme.bodyText)
                        }
                        .listRowBackground(DuelTheme.panelBg)
                    }
                    .listStyle(.plain)
                    .background(DuelTheme.bg)
                    .onAppear {
                        UITableView.appearance().backgroundColor = .clear
                    }
                }
            }
            .background(DuelTheme.bg)
            .navigationTitle("\(side.rawValue) 操作历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(DuelTheme.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func changeValueText(_ change: LPChange) -> String {
        switch change.type {
        case .damage: return "-\(change.value)"
        case .recover: return "+\(change.value)"
        case .pay: return "-\(change.value)"
        case .set: return "= \(change.value)"
        }
    }

    private func historyColor(_ type: LPChangeType) -> Color {
        switch type {
        case .damage: return DuelTheme.neonRed
        case .recover: return DuelTheme.neonGreen
        case .pay: return DuelTheme.neonOrange
        case .set: return DuelTheme.neonBlue
        }
    }
}
