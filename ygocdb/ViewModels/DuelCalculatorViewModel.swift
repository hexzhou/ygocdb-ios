//
//  DuelCalculatorViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/22.
//

import Foundation
import SwiftUI
import Combine

/// 决斗计算器 ViewModel
@MainActor
class DuelCalculatorViewModel: ObservableObject {
    // MARK: - LP 状态
    @Published var playerALP: Int = kInitialLP
    @Published var playerBLP: Int = kInitialLP
    @Published var playerAHistory: [LPChange] = []
    @Published var playerBHistory: [LPChange] = []

    // MARK: - 计时器
    @Published var elapsedSeconds: Int = 0
    @Published var isTimerRunning = false
    private var timerCancellable: AnyCancellable?
    private var backgroundDate: Date?

    // MARK: - 骰子 & 硬币
    @Published var diceResult: Int?
    @Published var coinResult: CoinResult?
    @Published var isDiceAnimating = false
    @Published var isCoinAnimating = false

    // MARK: - 错误提示
    @Published var showError = false
    @Published var errorMessage: String?

    // MARK: - 计时器格式化
    var timerDisplay: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - LP 操作

    /// 获取指定方的当前 LP
    func currentLP(for side: PlayerSide) -> Int {
        side == .playerA ? playerALP : playerBLP
    }

    /// 伤害：减少 LP，最低为 0
    func applyDamage(_ value: Int, to side: PlayerSide) {
        let current = currentLP(for: side)
        let result = max(0, current - value)
        let change = LPChange(type: .damage, value: value, resultLP: result)
        setLP(result, for: side)
        appendHistory(change, for: side)
    }

    /// 恢复：增加 LP
    func applyRecovery(_ value: Int, to side: PlayerSide) {
        let current = currentLP(for: side)
        let result = current + value
        let change = LPChange(type: .recover, value: value, resultLP: result)
        setLP(result, for: side)
        appendHistory(change, for: side)
    }

    /// 支付：减少 LP，余额不足时拒绝
    func applyPay(_ value: Int, to side: PlayerSide) {
        let current = currentLP(for: side)
        guard current >= value else {
            errorMessage = "LP 不足，无法支付"
            showError = true
            return
        }
        let result = current - value
        let change = LPChange(type: .pay, value: value, resultLP: result)
        setLP(result, for: side)
        appendHistory(change, for: side)
    }

    /// 设为：直接设置 LP
    func applySet(_ value: Int, to side: PlayerSide) {
        let change = LPChange(type: .set, value: value, resultLP: value)
        setLP(value, for: side)
        appendHistory(change, for: side)
    }

    /// 撤销最近一次操作
    func undoLastChange(for side: PlayerSide) {
        switch side {
        case .playerA:
            guard !playerAHistory.isEmpty else { return }
            playerAHistory.removeLast()
            playerALP = playerAHistory.last?.resultLP ?? kInitialLP
        case .playerB:
            guard !playerBHistory.isEmpty else { return }
            playerBHistory.removeLast()
            playerBLP = playerBHistory.last?.resultLP ?? kInitialLP
        }
    }

    private func setLP(_ value: Int, for side: PlayerSide) {
        switch side {
        case .playerA: playerALP = value
        case .playerB: playerBLP = value
        }
    }

    private func appendHistory(_ change: LPChange, for side: PlayerSide) {
        switch side {
        case .playerA: playerAHistory.append(change)
        case .playerB: playerBHistory.append(change)
        }
    }

    // MARK: - 计时器

    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }

    func pauseTimer() {
        isTimerRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func resetTimer() {
        pauseTimer()
        elapsedSeconds = 0
    }

    // MARK: - 后台时间补偿

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            if isTimerRunning {
                backgroundDate = Date()
            }
        case .active:
            if isTimerRunning, let bg = backgroundDate {
                let elapsed = Int(Date().timeIntervalSince(bg))
                elapsedSeconds += elapsed
                backgroundDate = nil
            }
        default:
            break
        }
    }

    // MARK: - 骰子 & 硬币

    func rollDice() {
        isDiceAnimating = true
        let result = Int.random(in: 1...6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.diceResult = result
            self?.isDiceAnimating = false
        }
    }

    func flipCoin() {
        isCoinAnimating = true
        let result: CoinResult = Bool.random() ? .heads : .tails
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.coinResult = result
            self?.isCoinAnimating = false
        }
    }

    // MARK: - 重置

    func resetDuel() {
        playerALP = kInitialLP
        playerBLP = kInitialLP
        playerAHistory = []
        playerBHistory = []
        resetTimer()
        diceResult = nil
        coinResult = nil
        isDiceAnimating = false
        isCoinAnimating = false
    }
}
