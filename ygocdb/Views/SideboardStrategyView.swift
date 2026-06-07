//
//  SideboardStrategyView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/31.
//

import SwiftUI

/// 副卡组策略列表
struct SideboardStrategyListView: View {
    @ObservedObject var deckViewModel: DeckBuilderViewModel
    let deckId: UUID

    @State private var strategies: [SideboardStrategy] = []
    @State private var editingStrategy: SideboardStrategy?
    @State private var showSharePreview = false
    @State private var previewImage: UIImage?

    private var currentDeck: Deck? {
        deckViewModel.decks.first(where: { $0.id == deckId }) ?? deckViewModel.currentDeck
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
                                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 50, height: 50)
                            Image(systemName: "rectangle.stack.fill")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(
                                    colors: [.blue, .purple],
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
                                Label("\(deck.sideDeckCount)", systemImage: "square.stack")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // 策略列表区域
                Section {
                    if strategies.isEmpty {
                        // 空状态 - 更友好的提示
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(LinearGradient(
                                    colors: [.gray.opacity(0.4), .gray.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                            Text("暂无换卡策略")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("点击下方按钮创建你的对局策略")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(strategies) { strategy in
                            StrategyListItem(
                                strategy: strategy,
                                onTap: { editingStrategy = strategy }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteStrategy(strategy)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // 新建策略按钮 - 更有吸引力的设计
                Section {
                    Button {
                        createNewStrategy()
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.green.opacity(0.2), Color.mint.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            }
                            
                            Text("新建策略")
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
        .navigationTitle("副卡组策略")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await generateSharePreview()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(currentDeck == nil || strategies.isEmpty)
            }
        }
        .onAppear {
            refreshDeck()
        }
        .onReceive(deckViewModel.$decks) { _ in
            refreshDeck()
        }
        .sheet(item: $editingStrategy) { strategy in
            if let deck = currentDeck {
                SideboardStrategyEditor(
                    deck: deck,
                    strategy: strategy,
                    onSave: { updated in
                        saveStrategy(updated, for: deck)
                    }
                )
            }
        }
        .sheet(isPresented: $showSharePreview) {
            DeckImagePreviewSheet(
                image: $previewImage,
                isPresented: $showSharePreview
            )
        }
    }

    private func refreshDeck() {
        if let deck = currentDeck {
            let sanitized = sanitizeStrategies(deck.sideboardStrategies, deck: deck)
            strategies = sanitized
            if sanitized != deck.sideboardStrategies {
                deckViewModel.updateSideboardStrategies(sanitized, for: deck)
            }
        }
    }

    private func saveStrategy(_ strategy: SideboardStrategy, for deck: Deck) {
        if let index = strategies.firstIndex(where: { $0.id == strategy.id }) {
            strategies[index] = strategy
        } else {
            strategies.append(strategy)
        }
        deckViewModel.updateSideboardStrategies(strategies, for: deck)
    }

    private func deleteStrategy(_ strategy: SideboardStrategy) {
        strategies.removeAll { $0.id == strategy.id }
        if let deck = currentDeck {
            deckViewModel.updateSideboardStrategies(strategies, for: deck)
        }
    }

    private func createNewStrategy() {
        var strategy = SideboardStrategy.defaultStrategy()
        strategy.vsDeckName = uniqueVSName(strategy.vsDeckName)
        strategies.append(strategy)
        if let deck = currentDeck {
            deckViewModel.updateSideboardStrategies(strategies, for: deck)
        }
        editingStrategy = strategy
    }

    private func uniqueVSName(_ base: String) -> String {
        var name = base
        var suffix = 1
        while strategies.contains(where: { $0.vsDeckName == name }) {
            suffix += 1
            name = "\(base) \(suffix)"
        }
        return name
    }

    @MainActor
    private func generateSharePreview() async {
        guard let deck = currentDeck else { return }
        let cardIds = collectStrategyCardIds(from: strategies)
        var cardImages: [Int: UIImage] = [:]

        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for cardId in cardIds {
                if let url = AppSettings.shared.cardImageLanguage.getImageURL(for: cardId, size: .thumb2) {
                    group.addTask {
                        if let cached = await ImageCache.shared.loadImage(for: url) {
                            return (cardId, cached)
                        }
                        let image = try? await ImageCache.shared.downloadAndCache(from: url)
                        return (cardId, image)
                    }
                }
            }

            for await (cardId, image) in group {
                if let image = image {
                    cardImages[cardId] = image
                }
            }
        }

        previewImage = renderStrategiesImage(deck: deck, strategies: strategies, cardImages: cardImages)
        showSharePreview = true
    }

    private func collectStrategyCardIds(from strategies: [SideboardStrategy]) -> [Int] {
        var ids = Set<Int>()
        for strategy in strategies {
            for change in strategy.first.swapOutMain + strategy.first.swapInMain + strategy.first.swapOutExtra + strategy.first.swapInExtra {
                ids.insert(change.cardId)
            }
            for change in strategy.second.swapOutMain + strategy.second.swapInMain + strategy.second.swapOutExtra + strategy.second.swapInExtra {
                ids.insert(change.cardId)
            }
        }
        return Array(ids)
    }

    private func renderStrategiesImage(
        deck: Deck,
        strategies: [SideboardStrategy],
        cardImages: [Int: UIImage]
    ) -> UIImage {
        // 字体配置
        let titleFont = UIFont.boldSystemFont(ofSize: 22)
        let vsFont = UIFont.boldSystemFont(ofSize: 11)
        let strategyFont = UIFont.boldSystemFont(ofSize: 16)
        let subtitleFont = UIFont.boldSystemFont(ofSize: 12)
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        
        // 尺寸配置
        let cardSize = CGSize(width: 38, height: 56)
        let labelWidth: CGFloat = 52
        let cardSpacing: CGFloat = 4
        let rowSpacing: CGFloat = 8
        let sectionSpacing: CGFloat = 16
        let strategySpacing: CGFloat = 24
        let padding: CGFloat = 20
        let maxColumns = 10
        let cornerRadius: CGFloat = 12
        let cardCornerRadius: CGFloat = 4
        
        // 颜色配置
        let backgroundColor = UIColor.systemBackground
        let cardBgColor = UIColor.tertiarySystemBackground
        let vsGradientColors = [UIColor.systemRed.cgColor, UIColor.systemOrange.cgColor]
        let firstColor = UIColor.systemBlue
        let secondColor = UIColor.systemPurple
        let swapOutColor = UIColor.systemRed
        let swapInColor = UIColor.systemGreen

        func expand(_ changes: [SideboardCardChange]) -> [Int] {
            changes.flatMap { Array(repeating: $0.cardId, count: max($0.count, 0)) }
        }

        func rowHeight(for count: Int) -> CGFloat {
            let rows = max(1, (count + maxColumns - 1) / maxColumns)
            return CGFloat(rows) * cardSize.height + CGFloat(rows - 1) * cardSpacing
        }

        // 计算总高度
        var totalHeight: CGFloat = padding + titleFont.lineHeight + sectionSpacing

        for strategy in strategies {
            // VS + 策略名称行
            totalHeight += strategyFont.lineHeight + sectionSpacing
            
            // 先攻卡片区域
            let firstOut = expand(strategy.first.swapOutMain + strategy.first.swapOutExtra)
            let firstIn = expand(strategy.first.swapInMain + strategy.first.swapInExtra)
            let firstCardHeight = 8 + subtitleFont.lineHeight + 10 + // 顶部padding + 标题 + 间距
                                  rowHeight(for: firstOut.count) + rowSpacing +
                                  rowHeight(for: firstIn.count) + 10 // 底部padding
            totalHeight += firstCardHeight + 8
            
            // 后攻卡片区域
            let secondOut = expand(strategy.second.swapOutMain + strategy.second.swapOutExtra)
            let secondIn = expand(strategy.second.swapInMain + strategy.second.swapInExtra)
            let secondCardHeight = 8 + subtitleFont.lineHeight + 10 +
                                   rowHeight(for: secondOut.count) + rowSpacing +
                                   rowHeight(for: secondIn.count) + 10
            totalHeight += secondCardHeight + strategySpacing
        }
        totalHeight += padding

        let contentWidth = padding * 2 + labelWidth + CGFloat(maxColumns) * cardSize.width + CGFloat(maxColumns - 1) * cardSpacing + 20
        let size = CGSize(width: contentWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制背景
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            var currentY: CGFloat = padding

            // 绘制标题
            let title = "\(deck.name) 副卡组策略"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            title.draw(at: CGPoint(x: padding, y: currentY), withAttributes: titleAttributes)
            currentY += titleFont.lineHeight + sectionSpacing

            // 绘制辅助函数
            func drawRoundedRect(at rect: CGRect, color: UIColor, cornerRadius: CGFloat) {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                color.setFill()
                path.fill()
            }
            
            func drawVSLabel(at point: CGPoint) {
                let vsRect = CGRect(x: point.x, y: point.y, width: 28, height: 18)
                let path = UIBezierPath(roundedRect: vsRect, cornerRadius: 4)
                cgContext.saveGState()
                cgContext.addPath(path.cgPath)
                cgContext.clip()
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: vsGradientColors as CFArray,
                                         locations: [0, 1])!
                cgContext.drawLinearGradient(gradient,
                                            start: CGPoint(x: vsRect.minX, y: vsRect.midY),
                                            end: CGPoint(x: vsRect.maxX, y: vsRect.midY),
                                            options: [])
                cgContext.restoreGState()
                
                let vsAttributes: [NSAttributedString.Key: Any] = [
                    .font: vsFont,
                    .foregroundColor: UIColor.white
                ]
                let vsSize = "VS".size(withAttributes: vsAttributes)
                "VS".draw(at: CGPoint(x: vsRect.midX - vsSize.width/2, y: vsRect.midY - vsSize.height/2), withAttributes: vsAttributes)
            }
            
            func drawColorIndicator(at point: CGPoint, color: UIColor, height: CGFloat) {
                let indicatorRect = CGRect(x: point.x, y: point.y, width: 3, height: height)
                let path = UIBezierPath(roundedRect: indicatorRect, cornerRadius: 1.5)
                color.setFill()
                path.fill()
            }
            
            func drawSwapIcon(at point: CGPoint, isOut: Bool) {
                let iconFont = UIFont.systemFont(ofSize: 10, weight: .bold)
                let iconText = isOut ? "↓" : "↑"
                let iconColor = isOut ? swapOutColor : swapInColor
                let iconAttributes: [NSAttributedString.Key: Any] = [
                    .font: iconFont,
                    .foregroundColor: iconColor
                ]
                iconText.draw(at: point, withAttributes: iconAttributes)
            }

            func drawCardRow(label: String, isOut: Bool, cardIds: [Int], startX: CGFloat, startY: CGFloat) -> CGFloat {
                // 绘制换出/换入图标和标签
                drawSwapIcon(at: CGPoint(x: startX, y: startY + (cardSize.height - labelFont.lineHeight) / 2 - 2), isOut: isOut)
                
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: labelFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                label.draw(at: CGPoint(x: startX + 14, y: startY + (cardSize.height - labelFont.lineHeight) / 2), withAttributes: labelAttributes)

                // 绘制卡片
                for (index, cardId) in cardIds.enumerated() {
                    let row = index / maxColumns
                    let col = index % maxColumns
                    let x = startX + labelWidth + CGFloat(col) * (cardSize.width + cardSpacing)
                    let y = startY + CGFloat(row) * (cardSize.height + cardSpacing)
                    let rect = CGRect(x: x, y: y, width: cardSize.width, height: cardSize.height)
                    
                    if let image = cardImages[cardId] {
                        // 绘制卡片阴影
                        cgContext.saveGState()
                        cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.1).cgColor)
                        let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: cardCornerRadius)
                        cgContext.addPath(cardPath.cgPath)
                        cgContext.clip()
                        image.draw(in: rect)
                        cgContext.restoreGState()
                    } else {
                        drawRoundedRect(at: rect, color: UIColor.systemGray5, cornerRadius: cardCornerRadius)
                    }
                }

                return startY + rowHeight(for: cardIds.count)
            }
            
            func drawStrategyCard(title: String, accentColor: UIColor, swapOut: [Int], swapIn: [Int], startY: CGFloat) -> CGFloat {
                let cardPadding: CGFloat = 10
                let cardHeight = cardPadding + subtitleFont.lineHeight + 10 +
                                 rowHeight(for: swapOut.count) + rowSpacing +
                                 rowHeight(for: swapIn.count) + cardPadding
                let cardRect = CGRect(x: padding, y: startY, width: contentWidth - padding * 2, height: cardHeight)
                
                // 绘制卡片背景
                drawRoundedRect(at: cardRect, color: cardBgColor, cornerRadius: cornerRadius)
                
                // 绘制边框
                let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
                accentColor.withAlphaComponent(0.15).setStroke()
                borderPath.lineWidth = 1
                borderPath.stroke()
                
                var innerY = startY + cardPadding
                let innerX = padding + cardPadding
                
                // 绘制颜色指示器和标题
                drawColorIndicator(at: CGPoint(x: innerX, y: innerY + 2), color: accentColor, height: subtitleFont.lineHeight - 4)
                
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: accentColor
                ]
                title.draw(at: CGPoint(x: innerX + 8, y: innerY), withAttributes: titleAttributes)
                innerY += subtitleFont.lineHeight + 10
                
                // 绘制换出行
                innerY = drawCardRow(label: "换出", isOut: true, cardIds: swapOut, startX: innerX, startY: innerY) + rowSpacing
                
                // 绘制换入行
                innerY = drawCardRow(label: "换入", isOut: false, cardIds: swapIn, startX: innerX, startY: innerY)
                
                return startY + cardHeight
            }

            // 遍历策略绘制
            for strategy in strategies {
                // 绘制 VS 标签和策略名称
                drawVSLabel(at: CGPoint(x: padding, y: currentY))
                
                let name = strategy.vsDeckName.isEmpty ? "未命名对局" : strategy.vsDeckName
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: strategyFont,
                    .foregroundColor: UIColor.label
                ]
                name.draw(at: CGPoint(x: padding + 36, y: currentY - 1), withAttributes: nameAttributes)
                currentY += strategyFont.lineHeight + sectionSpacing

                // 绘制先攻卡片
                let firstOut = expand(strategy.first.swapOutMain + strategy.first.swapOutExtra)
                let firstIn = expand(strategy.first.swapInMain + strategy.first.swapInExtra)
                currentY = drawStrategyCard(title: "先攻", accentColor: firstColor, swapOut: firstOut, swapIn: firstIn, startY: currentY) + 8

                // 绘制后攻卡片
                let secondOut = expand(strategy.second.swapOutMain + strategy.second.swapOutExtra)
                let secondIn = expand(strategy.second.swapInMain + strategy.second.swapInExtra)
                currentY = drawStrategyCard(title: "后攻", accentColor: secondColor, swapOut: secondOut, swapIn: secondIn, startY: currentY) + strategySpacing
            }
        }
    }

    private func sanitizeStrategies(_ strategies: [SideboardStrategy], deck: Deck) -> [SideboardStrategy] {
        guard !hasExtraSide(deck) else { return strategies }
        return strategies.map { strategy in
            var updated = strategy
            updated.first.swapOutExtra = []
            updated.first.swapInExtra = []
            updated.second.swapOutExtra = []
            updated.second.swapInExtra = []
            return updated
        }
    }

    private func hasExtraSide(_ deck: Deck) -> Bool {
        deck.sideDeckCards.contains { isExtraDeckCard($0.cardId) }
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

/// 策略列表项组件 - 现代化卡片设计
private struct StrategyListItem: View {
    let strategy: SideboardStrategy
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 策略标题区域
            HStack {
                // 对手卡组名称
                HStack(spacing: 8) {
                    Text("VS")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    
                    Text(strategy.vsDeckName.isEmpty ? "未命名对局" : strategy.vsDeckName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 先攻/后攻卡片区域
            VStack(spacing: 8) {
                StrategyCard(
                    swapSet: strategy.first,
                    title: "先攻",
                    accentColor: .blue
                )
                StrategyCard(
                    swapSet: strategy.second,
                    title: "后攻",
                    accentColor: .purple
                )
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

/// 策略卡片组件 - 显示换入换出信息
private struct StrategyCard: View {
    let swapSet: SideboardSwapSet
    let title: String
    let accentColor: Color
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题区域带颜色指示器
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 14)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                
                Spacer()
            }

            // 换出换入区域
            VStack(alignment: .leading, spacing: 8) {
                swapRow(
                    label: "换出",
                    icon: "arrow.down.circle.fill",
                    iconColor: .red,
                    changes: combineChanges(main: swapSet.swapOutMain, extra: swapSet.swapOutExtra)
                )
                swapRow(
                    label: "换入",
                    icon: "arrow.up.circle.fill",
                    iconColor: .green,
                    changes: combineChanges(main: swapSet.swapInMain, extra: swapSet.swapInExtra)
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private struct ChangeDisplay {
        let cardId: Int
        let count: Int
        let isExtra: Bool
    }

    private struct CardInstance: Identifiable {
        let id: String
        let cardId: Int
        let isExtra: Bool
    }

    private func combineChanges(main: [SideboardCardChange], extra: [SideboardCardChange]) -> [ChangeDisplay] {
        let mainItems = main.filter { $0.count > 0 }.map { ChangeDisplay(cardId: $0.cardId, count: $0.count, isExtra: false) }
        let extraItems = extra.filter { $0.count > 0 }.map { ChangeDisplay(cardId: $0.cardId, count: $0.count, isExtra: true) }
        return (mainItems + extraItems).sorted { $0.cardId < $1.cardId }
    }

    private func swapRow(label: String, icon: String, iconColor: Color, changes: [ChangeDisplay]) -> some View {
        var counter = 0
        let expanded: [CardInstance] = changes.flatMap { change in
            (0..<max(change.count, 0)).map { _ in
                defer { counter += 1 }
                return CardInstance(
                    id: "\(change.cardId)-\(change.isExtra)-\(counter)",
                    cardId: change.cardId,
                    isExtra: change.isExtra
                )
            }
        }
        return HStack(spacing: 8) {
            // 换出/换入标签
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)
            
            if expanded.isEmpty {
                Text("未设置")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            } else {
                if #available(iOS 16.0, *) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 4) {
                            ForEach(expanded) { item in
                                ZStack(alignment: .bottomTrailing) {
                                    cardThumbnail(item.cardId)
                                    if item.isExtra {
                                        Text("EX")
                                            .font(.system(size: 7, weight: .bold))
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(
                                                Capsule()
                                                    .fill(Color.purple)
                                            )
                                            .foregroundColor(.white)
                                            .offset(x: 2, y: 2)
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 4) {
                            ForEach(expanded) { item in
                                ZStack(alignment: .bottomTrailing) {
                                    cardThumbnail(item.cardId)
                                    if item.isExtra {
                                        Text("EX")
                                            .font(.system(size: 7, weight: .bold))
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(
                                                Capsule()
                                                    .fill(Color.purple)
                                            )
                                            .foregroundColor(.white)
                                            .offset(x: 2, y: 2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cardThumbnail(_ cardId: Int) -> some View {
        if let url = settings.cardImageLanguage.getImageURL(for: cardId, size: .thumb2) {
            if #available(iOS 16.0, *) {
                CachedAsyncImage(url: url, cacheKey: "side-strategy-thumb2-\(cardId)") { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }
                .frame(width: 36, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                CachedAsyncImage(url: url, cacheKey: "side-strategy-thumb2-\(cardId)") { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }
                .frame(width: 36, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 36, height: 52)
                .overlay(
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.5))
                )
        }
    }
}

/// 策略编辑 Sheet
private struct SideboardStrategyEditor: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SideboardStrategy
    @State private var activeOrder: SideboardPlayOrder = .first
    @State private var showSwapOutPicker = false
    @State private var showSwapInPicker = false
    @ObservedObject private var settings = AppSettings.shared

    init(deck: Deck, strategy: SideboardStrategy, onSave: @escaping (SideboardStrategy) -> Void) {
        self.deck = deck
        self._draft = State(initialValue: strategy)
        if strategy.first == SideboardSwapSet() && strategy.second != SideboardSwapSet() {
            self._activeOrder = State(initialValue: .second)
        }
        self.onSave = onSave
    }

    let onSave: (SideboardStrategy) -> Void

    var body: some View {
        NavigationView {
            Form {
                // 基础设置区域
                Section {
                    HStack(spacing: 12) {
                        // 装饰性图标
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.red.opacity(0.15), Color.orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 40, height: 40)
                            Text("VS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        
                        TextField("对战卡组名称", text: $draft.vsDeckName)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                    
                    Picker("先后手", selection: $activeOrder) {
                        ForEach(SideboardPlayOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // 换出卡片区域
                Section(header: HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text("换出卡片")
                }) {
                    Button {
                        showSwapOutPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            
                            Text("选择换出卡片")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    strategyCardSummary(currentSwapSet.swapOutMain)
                    if hasExtraSide && !currentSwapSet.swapOutExtra.isEmpty {
                        strategyCardSummary(currentSwapSet.swapOutExtra, label: "额外")
                    }
                }

                // 换入卡片区域
                Section(header: HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("换入卡片")
                }) {
                    Button {
                        showSwapInPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            
                            Text("选择换入卡片")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    strategyCardSummary(currentSwapSet.swapInMain)
                    if !currentSwapSet.swapInExtra.isEmpty {
                        strategyCardSummary(currentSwapSet.swapInExtra, label: "额外")
                    }
                }

                // 状态统计
                Section(footer: footerText.foregroundColor(isCurrentBalanced ? .secondary : .red)) {
                    EmptyView()
                }
            }
            .navigationTitle("编辑策略")
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
                    .disabled(!isAllBalanced)
                }
            }
            .sheet(isPresented: $showSwapOutPicker) {
                let sections: [CardCountSection] = {
                    var items = [CardCountSection(title: "主卡组", cards: groupCardCounts(deck.mainDeckCards))]
                    if hasExtraSide && !deck.extraDeckCards.isEmpty {
                        items.append(CardCountSection(title: "额外卡组", cards: groupCardCounts(deck.extraDeckCards)))
                    }
                    return items
                }()
                if #available(iOS 16.0, *) {
                    CardCountPickerSheet(
                        title: "换出卡片",
                        sections: sections,
                        selectedCounts: Binding(
                            get: { countsFromChanges(mergeChanges(main: currentSwapSet.swapOutMain, extra: currentSwapSet.swapOutExtra)) },
                            set: { applySwapOutCounts($0) }
                        )
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                } else {
                    CardCountPickerSheet(
                        title: "换出卡片",
                        sections: sections,
                        selectedCounts: Binding(
                            get: { countsFromChanges(mergeChanges(main: currentSwapSet.swapOutMain, extra: currentSwapSet.swapOutExtra)) },
                            set: { applySwapOutCounts($0) }
                        )
                    )
                }
            }
            .sheet(isPresented: $showSwapInPicker) {
                if #available(iOS 16.0, *) {
                    CardCountPickerSheet(
                        title: "换入卡片",
                        sections: [
                            CardCountSection(title: "副卡组", cards: groupCardCounts(deck.sideDeckCards))
                        ],
                        selectedCounts: Binding(
                            get: { countsFromChanges(mergeChanges(main: currentSwapSet.swapInMain, extra: currentSwapSet.swapInExtra)) },
                            set: { applySwapInCounts($0) }
                        )
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                } else {
                    CardCountPickerSheet(
                        title: "换入卡片",
                        sections: [
                            CardCountSection(title: "副卡组", cards: groupCardCounts(deck.sideDeckCards))
                        ],
                        selectedCounts: Binding(
                            get: { countsFromChanges(mergeChanges(main: currentSwapSet.swapInMain, extra: currentSwapSet.swapInExtra)) },
                            set: { applySwapInCounts($0) }
                        )
                    )
                }
            }
        }
    }

    private var footerText: Text {
        var text = Text("主卡组换出 \(totalCount(currentSwapSet.swapOutMain)) 张 / 换入 \(totalCount(currentSwapSet.swapInMain)) 张")
        if hasExtraSide {
            text = text
            + Text("\n")
            + Text("额外换出 \(totalCount(currentSwapSet.swapOutExtra)) 张 / 换入 \(totalCount(currentSwapSet.swapInExtra)) 张")
        }
        return text
    }

    private func strategyCardSummary(_ changes: [SideboardCardChange], label: String? = nil) -> some View {
        let summary = changes.filter { $0.count > 0 }.sorted { $0.cardId < $1.cardId }
        var counter = 0
        let expanded: [StrategyCardInstance] = summary.flatMap { change in
            (0..<max(change.count, 0)).map { _ in
                defer { counter += 1 }
                return StrategyCardInstance(id: "\(change.cardId)-\(counter)", cardId: change.cardId)
            }
        }

        return VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if expanded.isEmpty {
                Text("未选择")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(expanded) { item in
                            cardThumbnail(item.cardId)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private struct StrategyCardInstance: Identifiable {
        let id: String
        let cardId: Int
    }

    private func groupCardCounts(_ items: [DeckCardItem]) -> [StrategyDeckCardCount] {
        let grouped = Dictionary(grouping: items, by: { $0.cardId })
        return grouped.map { StrategyDeckCardCount(cardId: $0.key, count: $0.value.count) }
            .sorted { $0.cardId < $1.cardId }
    }

    private func isExtraDeckCard(_ cardId: Int) -> Bool {
        if let card = CardRepository.shared.getCard(byId: cardId),
           let type = card.data?.type {
            let cardType = CardType(rawValue: type)
            return cardType.contains(.fusion) || cardType.contains(.synchro) || cardType.contains(.xyz) || cardType.contains(.link)
        }
        return false
    }

    private func countsFromChanges(_ changes: [SideboardCardChange]) -> [Int: Int] {
        changes.reduce(into: [Int: Int]()) { $0[$1.cardId] = $1.count }
    }

    private func changesFromCounts(_ counts: [Int: Int]) -> [SideboardCardChange] {
        counts.compactMap { (key, value) in
            value > 0 ? SideboardCardChange(cardId: key, count: value) : nil
        }
        .sorted { $0.cardId < $1.cardId }
    }

    private func mergeChanges(main: [SideboardCardChange], extra: [SideboardCardChange]) -> [SideboardCardChange] {
        (main + extra).sorted { $0.cardId < $1.cardId }
    }

    private func applySwapOutCounts(_ counts: [Int: Int]) {
        var main: [SideboardCardChange] = []
        var extra: [SideboardCardChange] = []
        let extraIds = Set(deck.extraDeckCards.map { $0.cardId })
        for (cardId, count) in counts where count > 0 {
            let change = SideboardCardChange(cardId: cardId, count: count)
            if extraIds.contains(cardId) {
                extra.append(change)
            } else {
                main.append(change)
            }
        }
        updateCurrentSwapSet { set in
            set.swapOutMain = main.sorted { $0.cardId < $1.cardId }
            set.swapOutExtra = hasExtraSide ? extra.sorted { $0.cardId < $1.cardId } : []
        }
    }

    private func applySwapInCounts(_ counts: [Int: Int]) {
        var main: [SideboardCardChange] = []
        var extra: [SideboardCardChange] = []
        for (cardId, count) in counts where count > 0 {
            let change = SideboardCardChange(cardId: cardId, count: count)
            if isExtraDeckCard(cardId) {
                extra.append(change)
            } else {
                main.append(change)
            }
        }
        updateCurrentSwapSet { set in
            set.swapInMain = main.sorted { $0.cardId < $1.cardId }
            set.swapInExtra = hasExtraSide ? extra.sorted { $0.cardId < $1.cardId } : []
        }
    }

    private func totalCount(_ changes: [SideboardCardChange]) -> Int {
        changes.reduce(0) { $0 + $1.count }
    }

    private var isCurrentBalanced: Bool {
        let set = currentSwapSet
        return totalCount(set.swapOutMain) == totalCount(set.swapInMain)
            && totalCount(set.swapOutExtra) == totalCount(set.swapInExtra)
    }

    private var isAllBalanced: Bool {
        isBalanced(draft.first) && isBalanced(draft.second)
    }

    private func isBalanced(_ set: SideboardSwapSet) -> Bool {
        totalCount(set.swapOutMain) == totalCount(set.swapInMain)
            && totalCount(set.swapOutExtra) == totalCount(set.swapInExtra)
    }

    private var currentSwapSet: SideboardSwapSet {
        activeOrder == .first ? draft.first : draft.second
    }

    private func updateCurrentSwapSet(_ update: (inout SideboardSwapSet) -> Void) {
        if activeOrder == .first {
            var set = draft.first
            update(&set)
            draft.first = set
        } else {
            var set = draft.second
            update(&set)
            draft.second = set
        }
    }

    private var hasExtraSide: Bool {
        deck.sideDeckCards.contains { isExtraDeckCard($0.cardId) }
    }

    @ViewBuilder
    private func cardThumbnail(_ cardId: Int) -> some View {
        if let url = settings.cardImageLanguage.getImageURL(for: cardId, size: .thumb2) {
            CachedAsyncImage(url: url, cacheKey: "side-strategy-thumb2-\(cardId)") { image in
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

private struct StrategyDeckCardCount: Identifiable {
    let cardId: Int
    let count: Int
    var id: Int { cardId }
}

private struct CardCountSection: Identifiable {
    let title: String
    let cards: [StrategyDeckCardCount]
    var id: String { title }
}

/// 卡片数量选择 Sheet
private struct CardCountPickerSheet: View {
    let title: String
    let sections: [CardCountSection]
    @Binding var selectedCounts: [Int: Int]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    // 计算总选中数量
    private var totalSelected: Int {
        selectedCounts.values.reduce(0, +)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部统计条
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("已选择")
                            .font(.subheadline)
                        Text("\(totalSelected)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("张")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    // 清空按钮
                    if totalSelected > 0 {
                        Button {
                            withAnimation {
                                selectedCounts = [:]
                            }
                        } label: {
                            Text("清空")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                
                List {
                    ForEach(sections) { section in
                        if !section.cards.isEmpty {
                            Section(header: Text(section.title)) {
                                ForEach(section.cards) { item in
                                    let count = selectedCounts[item.cardId, default: 0]
                                    HStack(spacing: 12) {
                                        // 卡片缩略图
                                        cardThumbnail(item.cardId)
                                        
                                        // 卡片信息
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(cardName(item.cardId))
                                                .font(.subheadline)
                                                .fontWeight(count > 0 ? .semibold : .regular)
                                                .lineLimit(1)
                                            
                                            HStack(spacing: 4) {
                                                Text("可用")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("\(item.count)")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.orange)
                                                Text("张")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // 数量选择器
                                        HStack(spacing: 0) {
                                            // 减少按钮
                                            Button {
                                                if count > 0 {
                                                    withAnimation(.easeInOut(duration: 0.15)) {
                                                        selectedCounts[item.cardId] = count - 1
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "minus")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(count > 0 ? .blue : .gray.opacity(0.4))
                                                    .frame(width: 36, height: 36)
                                                    .background(count > 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(count == 0)
                                            
                                            // 当前数量
                                            Text("\(count)")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(count > 0 ? .blue : .secondary)
                                                .frame(width: 32)
                                            
                                            // 增加按钮
                                            Button {
                                                if count < item.count {
                                                    withAnimation(.easeInOut(duration: 0.15)) {
                                                        selectedCounts[item.cardId] = count + 1
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(count < item.count ? .blue : .gray.opacity(0.4))
                                                    .frame(width: 36, height: 36)
                                                    .background(count < item.count ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(count >= item.count)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(
                                        count > 0 
                                            ? Color.blue.opacity(0.05)
                                            : Color.clear
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    @ViewBuilder
    private func cardThumbnail(_ cardId: Int) -> some View {
        if let url = settings.cardImageLanguage.getImageURL(for: cardId, size: .thumb2) {
            CachedAsyncImage(url: url, cacheKey: "side-strategy-thumb2-\(cardId)") { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 40, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func cardName(_ cardId: Int) -> String {
        if let card = CardRepository.shared.getCard(byId: cardId) {
            return settings.getDisplayName(for: card)
        }
        return "#\(cardId)"
    }
}
