//
//  DeckLimitCheckView.swift
//  ygocdb
//

import SwiftUI

struct DeckLimitCheckView: View {
    let deck: Deck
    @ObservedObject var viewModel: DeckLimitCheckViewModel
    @State private var showAllMatchingLists = false

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.response == nil {
                loadingView
            } else if let errorMessage = viewModel.errorMessage, viewModel.response == nil {
                errorView(message: errorMessage)
            } else if viewModel.response != nil {
                reportView
            } else {
                loadingView
            }
        }
        .navigationTitle("禁卡表检查")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("更新禁卡表")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.1)
            Text("正在检查卡组…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42, weight: .medium))
                .foregroundColor(.orange)
            Text("暂时无法检查禁卡表")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("重新加载", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var reportView: some View {
        let evaluations = viewModel.evaluations(for: deck)
        let current = viewModel.currentEvaluation(for: deck)
        let matching = evaluations.filter { $0.outcome == .compliant }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker("对战环境", selection: $viewModel.selectedEnvironment) {
                    ForEach(LimitEnvironment.allCases) { environment in
                        Text(environment.displayName).tag(environment)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if let current {
                    DeckLimitResultHeader(
                        environment: viewModel.selectedEnvironment,
                        evaluation: current
                    )

                    if !current.violations.isEmpty {
                        DeckLimitViolationSection(violations: current.violations)
                    }

                    if !current.unresolvedCards.isEmpty {
                        UnresolvedDeckCardsSection(cards: current.unresolvedCards)
                    }

                    matchingListsSection(
                        matching: matching,
                        currentDate: current.date
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("判定说明", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                    Text("主卡组、额外卡组和副卡组中相同 CID 的卡片会合并计算。这里只检查禁限投入张数；历史卡表不校验卡片在当时是否已经发售。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedEnvironment) { _ in
            showAllMatchingLists = false
        }
    }

    private func matchingListsSection(
        matching: [DeckLimitEvaluation],
        currentDate: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("符合的禁卡表")
                        .font(.headline)
                    Text(matching.isEmpty ? "没有找到可确认符合的卡表" : "共符合 \(matching.count) 期")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let latest = matching.first {
                    Text("最近 \(formattedDate(latest.date))")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                }
            }

            if matching.isEmpty {
                Text("修正当前违规卡片后，这里会列出可使用的当前及历史禁卡表。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(matching.prefix(6))) { evaluation in
                    MatchingLimitListRow(
                        evaluation: evaluation,
                        isCurrent: evaluation.date == currentDate
                    )
                }

                if matching.count > 6 {
                    DisclosureGroup(
                        isExpanded: $showAllMatchingLists,
                        content: {
                            VStack(spacing: 0) {
                                ForEach(Array(matching.dropFirst(6))) { evaluation in
                                    MatchingLimitListRow(
                                        evaluation: evaluation,
                                        isCurrent: evaluation.date == currentDate
                                    )
                                    .padding(.top, 10)
                                }
                            }
                        },
                        label: {
                            Text("查看其余 \(matching.count - 6) 期")
                                .font(.subheadline.weight(.medium))
                        }
                    )
                    .tint(.accentColor)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DeckLimitCheckSummaryView: View {
    let environment: LimitEnvironment
    let evaluation: DeckLimitEvaluation?
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tintColor)
                .frame(width: 38, height: 38)
                .background(tintColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("禁卡表检查")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isLoading, evaluation == nil {
                ProgressView()
            } else {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(tintColor)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看卡组禁卡表检查详情")
    }

    private var subtitle: String {
        if let evaluation {
            return "\(environment.displayName) · \(formattedDate(evaluation.date)) 起适用"
        }
        if errorMessage != nil {
            return "禁卡表暂时无法读取"
        }
        return "\(environment.displayName) · 正在读取禁卡表"
    }

    private var statusText: String {
        guard let evaluation else {
            return errorMessage == nil ? "检查中" : "重试"
        }

        switch evaluation.outcome {
        case .empty:
            return "卡组为空"
        case .compliant:
            return "符合"
        case .noncompliant:
            return "\(evaluation.violations.count) 项违规"
        case .incomplete:
            return "无法完整判定"
        }
    }

    private var iconName: String {
        guard let evaluation else {
            return errorMessage == nil ? "checkmark.shield" : "exclamationmark.triangle"
        }

        switch evaluation.outcome {
        case .empty:
            return "checkmark.shield"
        case .compliant:
            return "checkmark.shield.fill"
        case .noncompliant:
            return "xmark.shield.fill"
        case .incomplete:
            return "questionmark.diamond.fill"
        }
    }

    private var tintColor: Color {
        guard let evaluation else {
            return errorMessage == nil ? .accentColor : .orange
        }

        switch evaluation.outcome {
        case .empty:
            return .secondary
        case .compliant:
            return .green
        case .noncompliant:
            return .red
        case .incomplete:
            return .orange
        }
    }
}

private struct DeckLimitResultHeader: View {
    let environment: LimitEnvironment
    let evaluation: DeckLimitEvaluation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(tintColor)
                .frame(width: 48, height: 48)
                .background(tintColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text("\(environment.fullName) · \(formattedDate(evaluation.date)) 起适用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(detailText)
                    .font(.subheadline)
                    .foregroundColor(tintColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tintColor.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tintColor.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var title: String {
        switch evaluation.outcome {
        case .empty:
            return "卡组为空"
        case .compliant:
            return "符合当前禁卡表"
        case .noncompliant:
            return "不符合当前禁卡表"
        case .incomplete:
            return "无法完整判定"
        }
    }

    private var detailText: String {
        switch evaluation.outcome {
        case .empty:
            return "添加卡片后即可自动检查"
        case .compliant:
            return "已检查 \(evaluation.checkedCardCount) 张卡片，没有超过投入上限"
        case .noncompliant:
            return "发现 \(evaluation.violations.count) 种卡片超过投入上限"
        case .incomplete:
            return "有 \(evaluation.unresolvedCardCount) 张卡片无法映射到官网 CID"
        }
    }

    private var iconName: String {
        switch evaluation.outcome {
        case .empty:
            return "checkmark.shield"
        case .compliant:
            return "checkmark.shield.fill"
        case .noncompliant:
            return "xmark.shield.fill"
        case .incomplete:
            return "questionmark.diamond.fill"
        }
    }

    private var tintColor: Color {
        switch evaluation.outcome {
        case .empty:
            return .secondary
        case .compliant:
            return .green
        case .noncompliant:
            return .red
        case .incomplete:
            return .orange
        }
    }
}

private struct DeckLimitViolationSection: View {
    let violations: [DeckLimitViolation]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("违规卡片")
                    .font(.headline)
                Spacer()
                Text("\(violations.count) 种")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            ForEach(Array(violations.enumerated()), id: \.element.id) { index, violation in
                DeckLimitViolationRow(violation: violation)
                if index != violations.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DeckLimitViolationRow: View {
    let violation: DeckLimitViolation
    @ObservedObject private var settings = AppSettings.shared

    private var card: Card? {
        CardRepository.shared.getCard(byCID: violation.cid)
    }

    var body: some View {
        Group {
            if let card {
                NavigationLink(destination: CardDetailView(card: card)) {
                    rowContent(card: card)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(card: nil)
            }
        }
    }

    private func rowContent(card: Card?) -> some View {
        HStack(spacing: 12) {
            cardImage(card)

            VStack(alignment: .leading, spacing: 4) {
                Text(violation.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("投入 \(violation.actualCount) 张 · 上限 \(violation.allowedCount) 张")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.red)
                Text(sectionSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(violation.status?.displayName ?? "超过上限")
                .font(.caption2.weight(.semibold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            if card != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func cardImage(_ card: Card?) -> some View {
        if let card {
            CachedAsyncImage(
                url: settings.getImageURL(for: card, size: .thumb2),
                cacheKey: "deck-limit-\(settings.cardImageLanguage.rawValue)-\(card.id)"
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                imagePlaceholder.overlay(ProgressView().scaleEffect(0.55))
            }
            .frame(width: 44, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            imagePlaceholder
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(UIColor.tertiarySystemFill))
            .overlay(
                Image(systemName: "rectangle.portrait")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }

    private var sectionSummary: String {
        var parts: [String] = []
        if violation.mainCount > 0 { parts.append("主卡组 \(violation.mainCount)") }
        if violation.extraCount > 0 { parts.append("额外 \(violation.extraCount)") }
        if violation.sideCount > 0 { parts.append("副卡组 \(violation.sideCount)") }
        return parts.joined(separator: " · ")
    }

    private var statusColor: Color {
        switch violation.status {
        case .forbidden:
            return .red
        case .limited:
            return .orange
        case .semiLimited:
            return Color(red: 0.70, green: 0.52, blue: 0.06)
        case nil:
            return .red
        }
    }
}

private struct UnresolvedDeckCardsSection: View {
    let cards: [UnresolvedDeckCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("无法判定的卡片", systemImage: "questionmark.diamond")
                .font(.headline)
                .foregroundColor(.orange)
            Text("这些卡片不在当前本地卡片数据库中，无法由密码映射到 CID，因此不会被计入合规结论。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(cards) { card in
                HStack {
                    Text(String(format: "%08d", card.cardID))
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Text("\(card.count) 张")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MatchingLimitListRow: View {
    let evaluation: DeckLimitEvaluation
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("\(formattedDate(evaluation.date)) 起适用")
                .font(.subheadline.monospacedDigit())
            Spacer()
            if isCurrent {
                Text("当前")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}

private func formattedDate(_ date: String) -> String {
    date.replacingOccurrences(of: "-", with: ".")
}

#Preview {
    NavigationView {
        DeckLimitCheckView(
            deck: Deck(name: "测试卡组"),
            viewModel: DeckLimitCheckViewModel()
        )
    }
}
