//
//  DeckBuilderView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import SwiftUI
import UIKit

/// 组卡器主视图
struct DeckBuilderView: View {
    let deck: Deck
    @StateObject private var viewModel = DeckBuilderViewModel()
    @StateObject private var searchViewModel = CardSearchViewModel()
    @StateObject private var filter = CardFilter()
    @State private var showFilter = false
    @State private var showAddCard = false
    @State private var selectedDeckType: DeckType = .main
    @State private var showHandTest = false
    @State private var displayMode: DisplayMode = .grid
    @State private var showShareDeckImage = false
    @State private var deckImage: UIImage?
    @State private var isGeneratingImage = false
    @State private var showProbabilityCalc = false
    @State private var showSideboardStrategies = false
    @State private var toastMessage: String?

    enum DisplayMode {
        case list
        case grid
    }

    var currentDeck: Deck {
        viewModel.decks.first(where: { $0.id == deck.id }) ?? deck
    }

    var body: some View {
        VStack(spacing: 0) {
            // 卡组内容
            Group {
                if displayMode == .list {
                    deckListView
                } else {
                    makeDeckGridView()
                }
            }

            Divider()

            // 底部操作栏
            DeckActionBar(
                onProbability: { showProbabilityCalc = true },
                onSideboard: { showSideboardStrategies = true },
                onAddCard: { showAddCard = true },
                onHandTest: {
                    showHandTest = true
                }
            )
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle(currentDeck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 切换显示模式
                    Button {
                        displayMode = displayMode == .list ? .grid : .list
                    } label: {
                        Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                    }

                    // 更多菜单
                    Menu {
                        Button {
                            exportDeck()
                        } label: {
                            Label("导出卡组", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            Task {
                                await generateDeckImage()
                            }
                        } label: {
                            Label("分享卡组图片", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareDeckImage) {
            DeckImagePreviewSheet(
                image: $deckImage,
                isPresented: $showShareDeckImage
            )
        }
        .background(
            NavigationLink(
                destination: ProbabilityCalcView(deckViewModel: viewModel, deckId: currentDeck.id),
                isActive: $showProbabilityCalc
            ) { EmptyView() }
        )
        .background(
            NavigationLink(
                destination: SideboardStrategyListView(deckViewModel: viewModel, deckId: currentDeck.id),
                isActive: $showSideboardStrategies
            ) { EmptyView() }
        )
        .sheet(isPresented: $showAddCard) {
            if #available(iOS 16.0, *) {
                DeckCardSearchView(
                    deck: currentDeck,
                    viewModel: viewModel,
                    searchViewModel: searchViewModel,
                    filter: filter
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            } else if #available(iOS 15.0, *) {
                DeckCardSearchView(
                    deck: currentDeck,
                    viewModel: viewModel,
                    searchViewModel: searchViewModel,
                    filter: filter
                )
                .background(SheetPresentationConfigurator())
            } else {
                DeckCardSearchView(
                    deck: currentDeck,
                    viewModel: viewModel,
                    searchViewModel: searchViewModel,
                    filter: filter
                )
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
        .sheet(isPresented: $showHandTest) {
            HandTestView(deck: currentDeck)
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    // 列表视图
    private var deckListView: some View {
        List {
            // 主卡组
            if !currentDeck.mainDeckCards.isEmpty {
                Section {
                    ForEach(groupCardsByID(currentDeck.mainDeckCards), id: \.cardId) { group in
                        DeckCardRowView(
                            cardId: group.cardId,
                            count: group.count,
                            deckType: .main,
                            onRemove: {
                                if let item = group.items.first {
                                    viewModel.removeCard(id: item.id, from: currentDeck)
                                }
                            },
                            onAdd: {
                                addCardFromContext(cardId: group.cardId, deckType: .main)
                            },
                            onMoveToSide: {
                                if let item = group.items.first {
                                    moveCardFromContext(itemId: item.id, cardId: group.cardId, to: .side)
                                }
                            }
                        )
                    }
                } header: {
                    Text("主卡组 (\(currentDeck.mainDeckCount))")
                }
            }

            // 额外卡组
            if !currentDeck.extraDeckCards.isEmpty {
                Section {
                    ForEach(groupCardsByID(currentDeck.extraDeckCards), id: \.cardId) { group in
                        DeckCardRowView(
                            cardId: group.cardId,
                            count: group.count,
                            deckType: .extra,
                            onRemove: {
                                if let item = group.items.first {
                                    viewModel.removeCard(id: item.id, from: currentDeck)
                                }
                            },
                            onAdd: {
                                addCardFromContext(cardId: group.cardId, deckType: .extra)
                            },
                            onMoveToSide: {
                                if let item = group.items.first {
                                    moveCardFromContext(itemId: item.id, cardId: group.cardId, to: .side)
                                }
                            }
                        )
                    }
                } header: {
                    Text("额外卡组 (\(currentDeck.extraDeckCount))")
                }
            }

            // 副卡组
            if !currentDeck.sideDeckCards.isEmpty {
                Section {
                    ForEach(groupCardsByID(currentDeck.sideDeckCards), id: \.cardId) { group in
                        DeckCardRowView(
                            cardId: group.cardId,
                            count: group.count,
                            deckType: .side,
                            onRemove: {
                                if let item = group.items.first {
                                    viewModel.removeCard(id: item.id, from: currentDeck)
                                }
                            },
                            onAdd: {
                                addCardFromContext(cardId: group.cardId, deckType: .side)
                            },
                            onMoveToMain: {
                                if let item = group.items.first {
                                    moveCardFromContext(itemId: item.id, cardId: group.cardId, to: .main)
                                }
                            },
                            onMoveToExtra: {
                                if let item = group.items.first {
                                    moveCardFromContext(itemId: item.id, cardId: group.cardId, to: .extra)
                                }
                            }
                        )
                    }
                } header: {
                    Text("副卡组 (\(currentDeck.sideDeckCount))")
                }
            }

            // 空状态
            if currentDeck.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("卡组为空")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("点击下方按钮添加卡片")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 300)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // 卡图网格视图
    @ViewBuilder
    private func makeDeckGridView() -> some View {
        let deck = currentDeck

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 主卡组
                if !deck.mainDeckCards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("主卡组")
                                .font(.headline)
                            Text("(\(deck.mainDeckCount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        DeckCardGridSection(
                            items: deck.mainDeckCards,
                            deckType: .main,
                            onAdd: { [self] cardId in
                                addCardFromContext(cardId: cardId, deckType: .main)
                            },
                            onRemove: { [self] itemId in
                                viewModel.removeCard(id: itemId, from: deck)
                            },
                            onMoveToSide: { [self] itemId, cardId in
                                moveCardFromContext(itemId: itemId, cardId: cardId, to: .side)
                            }
                        )
                    }
                }

                // 额外卡组
                if !deck.extraDeckCards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                            Text("额外卡组")
                                .font(.headline)
                            Text("(\(deck.extraDeckCount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        DeckCardGridSection(
                            items: deck.extraDeckCards,
                            deckType: .extra,
                            onAdd: { [self] cardId in
                                addCardFromContext(cardId: cardId, deckType: .extra)
                            },
                            onRemove: { [self] itemId in
                                viewModel.removeCard(id: itemId, from: deck)
                            },
                            onMoveToSide: { [self] itemId, cardId in
                                moveCardFromContext(itemId: itemId, cardId: cardId, to: .side)
                            }
                        )
                    }
                }

                // 副卡组
                if !deck.sideDeckCards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(.teal)
                            Text("副卡组")
                                .font(.headline)
                            Text("(\(deck.sideDeckCount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        DeckCardGridSection(
                            items: deck.sideDeckCards,
                            deckType: .side,
                            onAdd: { [self] cardId in
                                addCardFromContext(cardId: cardId, deckType: .side)
                            },
                            onRemove: { [self] itemId in
                                viewModel.removeCard(id: itemId, from: deck)
                            },
                            onMoveToMain: { [self] itemId, cardId in
                                moveCardFromContext(itemId: itemId, cardId: cardId, to: .main)
                            },
                            onMoveToExtra: { [self] itemId, cardId in
                                moveCardFromContext(itemId: itemId, cardId: cardId, to: .extra)
                            }
                        )
                    }
                }

                // 空状态
                if deck.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("卡组为空")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("点击下方按钮添加卡片")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 300)
                }
            }
            .padding(.vertical)
        }
    }

    /// 按卡片ID分组
    private func groupCardsByID(_ items: [DeckCardItem]) -> [CardGroup] {
        let grouped = Dictionary(grouping: items, by: { $0.cardId })
        return grouped.map { CardGroup(cardId: $0.key, items: $0.value) }
            .sorted { $0.cardId < $1.cardId }
    }

    /// 导出卡组
    private func exportDeck() {
        let code = currentDeck.exportToCode()
        UIPasteboard.general.string = code

        // 显示分享面板
        let activityVC = UIActivityViewController(
            activityItems: [code],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
            rootVC.present(activityVC, animated: true)
        }
    }

    /// 生成卡组图片
    @MainActor
    private func generateDeckImage() async {
        isGeneratingImage = true

        // 收集所有卡片图片
        var cardImages: [Int: UIImage] = [:]

        // 获取所有卡片 ID
        let allCardIds = Set(
            currentDeck.mainDeckCards.map(\.cardId) +
            currentDeck.extraDeckCards.map(\.cardId) +
            currentDeck.sideDeckCards.map(\.cardId)
        )

        // 异步下载所有卡图
        // 首先在主线程获取所有 URL
        var cardURLs: [Int: URL] = [:]
        for cardId in allCardIds {
            cardURLs[cardId] = AppSettings.shared.cardImageLanguage.getImageURL(for: cardId, size: .thumb2)
        }

        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (cardId, url) in cardURLs {
                group.addTask {
                    let image = try? await ImageCache.shared.downloadAndCache(from: url)
                    return (cardId, image)
                }
            }

            for await (cardId, image) in group {
                if let image = image {
                    cardImages[cardId] = image
                }
            }
        }

        // 生成卡组图片
        let image = renderDeckImage(cardImages: cardImages)
        deckImage = image
        isGeneratingImage = false
        showShareDeckImage = true
    }

    /// 渲染卡组图片
    private func renderDeckImage(cardImages: [Int: UIImage]) -> UIImage {
        let cardWidth: CGFloat = 44
        let cardHeight: CGFloat = cardWidth / 0.69
        let columns = 8
        let padding: CGFloat = 16
        let headerSpacing: CGFloat = 10
        let sectionSpacing: CGFloat = 20
        let cardSpacing: CGFloat = 4
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let headerFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let countFont = UIFont.systemFont(ofSize: 14)
        let iconSize: CGFloat = 14

        struct DeckSection {
            let title: String
            let iconName: String
            let iconColor: UIColor
            let cards: [DeckCardItem]
        }

        let sections: [DeckSection] = [
            DeckSection(title: "主卡组", iconName: "rectangle.stack.fill", iconColor: .systemBlue, cards: currentDeck.mainDeckCards),
            DeckSection(title: "额外卡组", iconName: "star.fill", iconColor: .systemPurple, cards: currentDeck.extraDeckCards),
            DeckSection(title: "副卡组", iconName: "arrow.left.arrow.right", iconColor: .systemTeal, cards: currentDeck.sideDeckCards)
        ].filter { !$0.cards.isEmpty }

        // 计算总高度
        let contentWidth = padding * 2 + CGFloat(columns) * cardWidth + CGFloat(columns - 1) * cardSpacing
        let headerHeight = max(iconSize, headerFont.lineHeight)
        let titleHeight = titleFont.lineHeight
        var totalHeight = padding + titleHeight + padding

        for (index, section) in sections.enumerated() {
            let rows = (section.cards.count + columns - 1) / columns
            totalHeight += headerHeight + headerSpacing + CGFloat(rows) * (cardHeight + cardSpacing) - cardSpacing
            if index != sections.count - 1 {
                totalHeight += sectionSpacing
            }
        }
        totalHeight += padding + 36

        let size = CGSize(width: contentWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // 背景色
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            var currentY: CGFloat = padding

            // 卡组名称
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            let title = currentDeck.name
            title.draw(at: CGPoint(x: padding, y: currentY), withAttributes: titleAttributes)
            currentY += titleHeight + padding

            func drawSectionHeader(
                title: String,
                count: Int,
                iconName: String,
                iconColor: UIColor,
                startY: CGFloat
            ) -> CGFloat {
                let iconRect = CGRect(x: padding, y: startY + (headerHeight - iconSize) / 2, width: iconSize, height: iconSize)
                if let icon = UIImage(systemName: iconName)?.withTintColor(iconColor, renderingMode: .alwaysOriginal) {
                    icon.draw(in: iconRect)
                }

                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.label
                ]
                let countAttributes: [NSAttributedString.Key: Any] = [
                    .font: countFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]

                let titleText = title as NSString
                let titleSize = titleText.size(withAttributes: titleAttributes)
                let titleX = padding + iconSize + 8
                let titleY = startY + (headerHeight - titleSize.height) / 2
                titleText.draw(at: CGPoint(x: titleX, y: titleY), withAttributes: titleAttributes)

                let countText = "(\(count))" as NSString
                let countX = titleX + titleSize.width + 4
                let countY = startY + (headerHeight - countFont.lineHeight) / 2
                countText.draw(at: CGPoint(x: countX, y: countY), withAttributes: countAttributes)

                return startY + headerHeight + headerSpacing
            }

            for (index, section) in sections.enumerated() {
                currentY = drawSectionHeader(
                    title: section.title,
                    count: section.cards.count,
                    iconName: section.iconName,
                    iconColor: section.iconColor,
                    startY: currentY
                )
                drawCardGrid(
                    cards: section.cards,
                    cardImages: cardImages,
                    startY: currentY,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    columns: columns,
                    padding: padding,
                    spacing: cardSpacing,
                    context: context
                )
                let rows = (section.cards.count + columns - 1) / columns
                currentY += CGFloat(rows) * (cardHeight + cardSpacing) - cardSpacing
                if index != sections.count - 1 {
                    currentY += sectionSpacing
                }
            }
        }
    }

    /// 绘制卡片网格
    private func drawCardGrid(
        cards: [DeckCardItem],
        cardImages: [Int: UIImage],
        startY: CGFloat,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        columns: Int,
        padding: CGFloat,
        spacing: CGFloat,
        context: UIGraphicsImageRendererContext
    ) {
        let sortedCards = cards.sorted {
            if $0.cardId == $1.cardId {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.cardId < $1.cardId
        }
        for (index, card) in sortedCards.enumerated() {
            let row = index / columns
            let col = index % columns
            let x = padding + CGFloat(col) * (cardWidth + spacing)
            let y = startY + CGFloat(row) * (cardHeight + spacing)
            let rect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)

            if let image = cardImages[card.cardId] {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                context.cgContext.saveGState()
                context.cgContext.addPath(path.cgPath)
                context.cgContext.clip()
                image.draw(in: rect)
                context.cgContext.restoreGState()
            } else {
                // 占位符
                UIColor.systemGray5.setFill()
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                context.cgContext.addPath(path.cgPath)
                context.cgContext.fillPath()
            }
        }
    }

    private func addCardFromContext(cardId: Int, deckType: DeckType) {
        let result = viewModel.addCard(cardId: cardId, to: deckType, in: currentDeck)
        switch result {
        case .limitReached:
            showToast("每张卡片最多只能添加3张")
        default:
            break
        }
    }

    private func moveCardFromContext(itemId: UUID, cardId: Int, to deckType: DeckType) {
        let result = viewModel.moveCard(itemId: itemId, cardId: cardId, to: deckType, in: currentDeck)
        switch result {
        case .limitReached:
            showToast("每张卡片最多只能添加3张")
        case .failed:
            showToast("移动失败")
        default:
            break
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

/// 卡片分组
struct CardGroup {
    let cardId: Int
    let items: [DeckCardItem]
    var count: Int { items.count }
}

/// 卡组统计视图
struct DeckStatisticsView: View {
    let deck: Deck

    var body: some View {
        HStack(spacing: 20) {
            StatisticItem(
                title: "主卡组",
                count: deck.mainDeckCount,
                color: .blue,
                icon: "rectangle.stack"
            )

            StatisticItem(
                title: "额外",
                count: deck.extraDeckCount,
                color: .purple,
                icon: "square.stack.3d.up"
            )

            StatisticItem(
                title: "副卡组",
                count: deck.sideDeckCount,
                color: .orange,
                icon: "square.stack"
            )
        }
    }
}

/// 统计项
struct StatisticItem: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 卡组卡片行视图
struct DeckCardRowView: View {
    let cardId: Int
    let count: Int
    let deckType: DeckType
    let onRemove: () -> Void
    let onAdd: () -> Void
    let onMoveToSide: () -> Void
    let onMoveToMain: () -> Void
    let onMoveToExtra: () -> Void

    @State private var selectedCard: Card?
    @State private var selectedPreReleaseCard: PreReleaseCard?
    @State private var preReleaseCard: PreReleaseCard?
    @State private var showMissingDataAlert = false
    @ObservedObject private var settings = AppSettings.shared

    init(
        cardId: Int,
        count: Int,
        deckType: DeckType,
        onRemove: @escaping () -> Void,
        onAdd: @escaping () -> Void,
        onMoveToSide: @escaping () -> Void = {},
        onMoveToMain: @escaping () -> Void = {},
        onMoveToExtra: @escaping () -> Void = {}
    ) {
        self.cardId = cardId
        self.count = count
        self.deckType = deckType
        self.onRemove = onRemove
        self.onAdd = onAdd
        self.onMoveToSide = onMoveToSide
        self.onMoveToMain = onMoveToMain
        self.onMoveToExtra = onMoveToExtra
        _selectedCard = State(initialValue: nil)
        _selectedPreReleaseCard = State(initialValue: nil)
        _preReleaseCard = State(initialValue: nil)
        _showMissingDataAlert = State(initialValue: false)
    }

    var card: Card? {
        CardRepository.shared.getCard(byId: cardId)
    }

    /// 是否为先行卡
    var isPreReleaseCard: Bool {
        card == nil && preReleaseCard != nil
    }

    var body: some View {
        Button {
            if let card = card {
                selectedCard = card
            } else if let preRelease = preReleaseCard {
                selectedPreReleaseCard = preRelease
            } else {
                showMissingDataAlert = true
            }
        } label: {
            HStack(spacing: 12) {
                // 卡图
                if let card = card {
                    CachedAsyncImage(
                        url: settings.getImageURL(for: card, size: .thumb2),
                        cacheKey: "deck-\(cardId)"
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .frame(width: 50, height: 73)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else if let preRelease = preReleaseCard {
                    CachedAsyncImage(
                        url: preRelease.imageURL,
                        cacheKey: "deck-prerelease-\(cardId)"
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .frame(width: 50, height: 73)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 73)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            Text("?")
                                .font(.title)
                                .foregroundColor(.gray)
                        )
                }

                // 卡片信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(card?.displayName ?? preReleaseCard?.name ?? "未知卡片")
                            .font(.body)
                            .lineLimit(1)

                        // 先行卡标识
                        if isPreReleaseCard {
                            Text("先行")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Text(card?.typesDisplay ?? preReleaseCard?.overallString ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 数量标签
                Text("×\(count)")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("移除", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                onAdd()
            } label: {
                Label("添加一张", systemImage: "plus.circle")
            }

            if deckType == .main || deckType == .extra {
                Button {
                    onMoveToSide()
                } label: {
                    Label("移到副卡组", systemImage: "arrow.left.arrow.right")
                }
            } else if deckType == .side {
                if isExtraDeckCard(cardId) {
                    Button {
                        onMoveToExtra()
                    } label: {
                        Label("移到额外卡组", systemImage: "square.stack.3d.up")
                    }
                } else {
                    Button {
                        onMoveToMain()
                    } label: {
                        Label("移到主卡组", systemImage: "rectangle.stack")
                    }
                }
            }

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("移除一张", systemImage: "minus.circle")
            }
        }
        .sheet(item: $selectedCard) { card in
            NavigationView {
                CardDetailView(card: card)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                selectedCard = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: $selectedPreReleaseCard) { card in
            NavigationView {
                PreReleaseCardDetailView(card: card)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                selectedPreReleaseCard = nil
                            }
                        }
                    }
            }
        }
        .alert("卡片数据未加载", isPresented: $showMissingDataAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请先在主界面下载/加载卡片数据库，或下载先行卡数据")
        }
        .task {
            // 如果正式卡库中找不到，尝试从先行卡获取
            if card == nil {
                // 先尝试从缓存获取
                if let cached = await PreReleaseCardService.shared.getCard(byId: cardId) {
                    preReleaseCard = cached
                } else {
                    // 缓存中没有，尝试加载先行卡数据后再获取
                    _ = try? await PreReleaseCardService.shared.fetchCards()
                    preReleaseCard = await PreReleaseCardService.shared.getCard(byId: cardId)
                }
            }
        }
    }

    private func isExtraDeckCard(_ cardId: Int) -> Bool {
        if let card = CardRepository.shared.getCard(byId: cardId),
           let type = card.data?.type {
            let cardType = CardType(rawValue: type)
            return cardType.contains(.fusion) || cardType.contains(.synchro) || cardType.contains(.xyz) || cardType.contains(.link)
        }
        return false
    }
}

/// 底部操作栏
struct DeckActionBar: View {
    let onProbability: () -> Void
    let onSideboard: () -> Void
    let onAddCard: () -> Void
    let onHandTest: () -> Void
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        HStack(spacing: 10) {
            // 概率计算按钮
            Button {
                onProbability()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "percent")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
            }

            // 副卡组策略按钮
            Button {
                onSideboard()
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

            // 添加卡片按钮（主按钮）
            Button {
                onAddCard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("添加卡片")
                        .font(.subheadline)
                        .fontWeight(.semibold)
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

            // 试抽按钮
            Button {
                onHandTest()
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
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
            }
        }
    }
}

/// 卡组图片预览分享视图
struct DeckImagePreviewSheet: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    @State private var showShareSheet = false
    @State private var toastMessage: String?
    @State private var watermarkEnabled = false
    @State private var displayImage: UIImage?

    private var exportImage: UIImage? {
        displayImage ?? image
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let image = exportImage {
                    // 图片预览区域
                    ScrollView {
                        VStack(spacing: 0) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 20)
                        }
                    }
                    .background(Color(UIColor.systemGroupedBackground))

                    // 底部操作按钮区域
                    VStack(spacing: 0) {
                        Divider()

                        HStack {
                            Label("添加水印", systemImage: watermarkEnabled ? "seal.fill" : "seal")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $watermarkEnabled)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemBackground))

                        Divider()
                        
                        HStack(spacing: 16) {
                            // 保存到相册按钮
                            Button {
                                saveToAlbum()
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    Text("保存到相册")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            // 分享按钮
                            Button {
                                showShareSheet = true
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    Text("分享")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                    }
                } else {
                    // 加载状态
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                        Text("正在生成图片...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            .navigationTitle("分享图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = exportImage {
                    ShareSheet(items: [image])
                }
            }
            .overlay(
                VStack {
                    Spacer()
                    if let message = toastMessage {
                        ToastView(message: message)
                            .padding(.bottom, 100)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: toastMessage)
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            updateDisplayImage()
        }
        .onChange(of: image) { _ in
            updateDisplayImage()
        }
        .onChange(of: watermarkEnabled) { _ in
            updateDisplayImage()
        }
    }

    /// 保存到相册
    private func saveToAlbum() {
        guard let image = exportImage else { return }

        if let jpegData = image.jpegData(compressionQuality: 0.95),
           let jpegImage = UIImage(data: jpegData) {
            UIImageWriteToSavedPhotosAlbum(jpegImage, nil, nil, nil)
            showToast("已保存到相册")
        } else {
            showToast("保存失败")
        }
    }

    /// 显示 Toast
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

    private func updateDisplayImage() {
        guard let baseImage = image else {
            displayImage = nil
            return
        }
        if watermarkEnabled {
            displayImage = applyWatermark(to: baseImage)
        } else {
            displayImage = baseImage
        }
    }

    private func applyWatermark(to image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            drawWatermark(in: context.cgContext, size: size)
        }
    }

    private func drawWatermark(in context: CGContext, size: CGSize) {
        let padding: CGFloat = 16
        let badgePaddingH: CGFloat = 12
        let spacing: CGFloat = 8

        let title = "游戏王查卡器"
        let titleFont = UIFont.systemFont(ofSize: 14, weight: .bold)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white
        ]

        let titleSize = (title as NSString).size(withAttributes: titleAttributes)
        
        // 图标大小等于徽章高度
        let iconSize: CGFloat = 36
        let badgeHeight = iconSize
        let badgeWidth = iconSize + spacing + titleSize.width + badgePaddingH
        
        let badgeOrigin = CGPoint(
            x: size.width - badgeWidth - padding,
            y: size.height - badgeHeight - padding
        )
        let badgeRect = CGRect(origin: badgeOrigin, size: CGSize(width: badgeWidth, height: badgeHeight))

        // 绘制毛玻璃背景
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeHeight / 2)
        context.saveGState()
        
        // 半透明深色背景
        context.setFillColor(UIColor(white: 0.1, alpha: 0.65).cgColor)
        context.addPath(badgePath.cgPath)
        context.fillPath()
        
        // 精致白色边框
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        context.addPath(badgePath.cgPath)
        context.setLineWidth(1.5)
        context.strokePath()
        context.restoreGState()

        // 绘制 App Icon（与左侧边缘重合）
        let iconRect = CGRect(
            x: badgeRect.minX,
            y: badgeRect.minY,
            width: iconSize,
            height: iconSize
        )
        
        context.saveGState()
        // 圆形裁剪
        let iconPath = UIBezierPath(ovalIn: iconRect)
        context.addPath(iconPath.cgPath)
        context.clip()
        
        // 绘制 App Icon
        if let appIcon = UIImage(named: "WatermarkIcon") {
            appIcon.draw(in: iconRect)
        }
        context.restoreGState()

        // 绘制文字（垂直居中）
        let textOriginX = iconRect.maxX + spacing
        let textY = badgeRect.midY - titleSize.height / 2
        (title as NSString).draw(at: CGPoint(x: textOriginX, y: textY), withAttributes: titleAttributes)
    }
}

@available(iOS 15.0, *)
private struct SheetPresentationConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let sheet = uiViewController.parent?.presentationController as? UISheetPresentationController else {
                return
            }
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }
}

#Preview {
    NavigationView {
        DeckBuilderView(deck: Deck(name: "测试卡组"))
    }
}
