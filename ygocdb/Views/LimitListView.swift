//
//  LimitListView.swift
//  ygocdb
//

import SwiftUI

/// OCG / 简中 / TCG 禁限卡表。
struct LimitListView: View {
    @StateObject private var viewModel = LimitListViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            content
                .navigationTitle("禁卡表")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("关闭") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.isLoading, viewModel.response != nil {
                            ProgressView()
                        }
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: "搜索卡名、密码或 CID")
                .task {
                    await viewModel.load()
                }
                .alert("无法更新禁卡表", isPresented: $viewModel.showRefreshError) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "请稍后重试")
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.response == nil {
            loadingView
        } else if let errorMessage = viewModel.errorMessage, viewModel.response == nil {
            errorView(message: errorMessage)
        } else if let list = viewModel.selectedList {
            limitList(list)
        } else {
            emptyView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.15)
            Text("正在加载禁卡表…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.orange)

            Text("暂时无法加载禁卡表")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.load(forceRefresh: true) }
            } label: {
                Label("重新加载", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("暂无禁卡表数据")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func limitList(_ list: LimitList) -> some View {
        let changesByCID = Dictionary(uniqueKeysWithValues: viewModel.changes.map { ($0.cid, $0) })

        return List {
            Section {
                LimitListOverview(
                    list: list,
                    selectedEnvironment: $viewModel.selectedEnvironment
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            if viewModel.hasSearchResults {
                ForEach(viewModel.visibleStatuses, id: \.rawValue) { status in
                    let entries = viewModel.entries(for: status)

                    Section {
                        ForEach(entries) { entry in
                            limitCardDestination(entry, change: changesByCID[entry.cid])
                        }
                    } header: {
                        LimitSectionHeader(status: status, count: entries.count)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            } else {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("没有找到相关卡片")
                            .font(.headline)
                        Text("可尝试卡片的中、日、英文名称、密码或 CID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }

            Section {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                    Text("数据来源：ygocdb.com")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func limitCardDestination(_ entry: LimitCardEntry, change: LimitListChange?) -> some View {
        if let card = CardRepository.shared.getCard(byCID: entry.cid) {
            NavigationLink(destination: CardDetailView(card: card)) {
                LimitCardRow(entry: entry, card: card, change: change)
            }
        } else {
            LimitCardRow(entry: entry, card: nil, change: change)
        }
    }
}

private struct LimitListOverview: View {
    let list: LimitList
    @Binding var selectedEnvironment: LimitEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("对战环境", selection: $selectedEnvironment) {
                ForEach(LimitEnvironment.allCases) { environment in
                    Text(environment.displayName).tag(environment)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedEnvironment.fullName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(list.date.replacingOccurrences(of: "-", with: ".")) 起适用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("共 \(list.totalCount) 张")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                LimitCountCell(status: .forbidden, count: list.count(for: .forbidden))
                LimitCountCell(status: .limited, count: list.count(for: .limited))
                LimitCountCell(status: .semiLimited, count: list.count(for: .semiLimited))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .contain)
    }
}

private struct LimitCountCell: View {
    let status: CardLimitStatus
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(status.shortDisplayName)
                .font(.caption)
        }
        .foregroundColor(status.tintColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(status.tintColor.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("\(status.displayName) \(count) 张")
    }
}

private struct LimitSectionHeader: View {
    let status: CardLimitStatus
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(status.tintColor)
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .fontWeight(.semibold)
            Spacer()
            Text("\(count) 张 · 最多投入 \(status.rawValue) 张")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(nil)
        }
    }
}

private struct LimitCardRow: View {
    let cid: Int
    let apiName: String
    let card: Card?
    let change: LimitListChange?
    @ObservedObject private var settings = AppSettings.shared

    init(entry: LimitCardEntry, card: Card?, change: LimitListChange?) {
        cid = entry.cid
        apiName = entry.apiName
        self.card = card
        self.change = change
    }

    private var primaryName: String {
        guard let card else { return apiName }
        return settings.getDisplayName(for: card)
    }

    private var additionalNames: [String] {
        var seen = Set([primaryName.lowercased()])
        let candidates = [apiName] + (card.map { settings.getAdditionalDisplayNames(for: $0) } ?? [])

        return Array(candidates.compactMap { name -> String? in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { return nil }
            return trimmed
        }.prefix(2))
    }

    var body: some View {
        HStack(spacing: 12) {
            cardImage

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(primaryName)
                        .font(settings.cardTitleFont())
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let change {
                        Text(change.transitionText)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(change.direction.tintColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(change.direction.tintColor.opacity(0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .fixedSize()
                    }
                }

                ForEach(additionalNames, id: \.self) { name in
                    Text(name)
                        .font(settings.cardCaptionFont())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let card {
                    Text(card.typesDisplay)
                        .font(settings.cardCaptionFont())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("CID \(cid)")
                        .font(settings.cardCaptionFont())
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var cardImage: some View {
        if let card {
            CachedAsyncImage(
                url: settings.getImageURL(for: card, size: .thumb2),
                cacheKey: "limit-\(settings.cardImageLanguage.rawValue)-\(card.id)-thumb2"
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                imagePlaceholder
                    .overlay(ProgressView().scaleEffect(0.65))
            }
            .frame(width: 60, height: 87)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            imagePlaceholder
                .frame(width: 60, height: 87)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(UIColor.tertiarySystemFill))
            .overlay(
                Image(systemName: "rectangle.portrait")
                    .foregroundColor(.secondary)
            )
    }
}

private extension LimitChangeDirection {
    var tintColor: Color {
        switch self {
        case .tightened:
            return .red
        case .relaxed:
            return .green
        }
    }
}

private extension CardLimitStatus {
    var shortDisplayName: String {
        switch self {
        case .forbidden:
            return "禁止"
        case .limited:
            return "限制"
        case .semiLimited:
            return "准限制"
        }
    }

    var tintColor: Color {
        switch self {
        case .forbidden:
            return .red
        case .limited:
            return .orange
        case .semiLimited:
            return Color(red: 0.70, green: 0.52, blue: 0.06)
        }
    }
}

#Preview {
    LimitListView()
}
