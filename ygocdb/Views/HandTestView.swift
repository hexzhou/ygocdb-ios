//
//  HandTestView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import SwiftUI

/// 抽到的卡片（支持正式卡和先行卡）
enum DrawnCard: Identifiable {
    case normal(Card)
    case preRelease(PreReleaseCard)

    var id: Int {
        switch self {
        case .normal(let card): return card.id
        case .preRelease(let card): return card.id
        }
    }

    var displayName: String {
        switch self {
        case .normal(let card): return card.displayName
        case .preRelease(let card): return card.name
        }
    }

    var isPreRelease: Bool {
        if case .preRelease = self { return true }
        return false
    }
}

/// 起手测试视图
struct HandTestView: View {
    let deck: Deck
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [DrawnCard] = []
    @State private var shuffledCardIds: [Int] = []
    @State private var nextDrawIndex: Int = 0
    @State private var showingCard: Card?
    @State private var showingPreReleaseCard: PreReleaseCard?
    @State private var drawSessionId = UUID()
    @State private var isLoading = false
    @State private var isTenDrawMode = false
    @State private var tenHands: [[DrawnCard]] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("加载卡片...")
                        .frame(maxHeight: .infinity)
                } else if !isTenDrawMode && cards.isEmpty && nextDrawIndex == 0 {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("主卡组卡片不足")
                            .font(.title2)

                        Text("至少需要5张卡片才能进行起手测试")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if isTenDrawMode {
                                Text("十连抽")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("起手 \(cards.count) 张")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }

                            if isTenDrawMode {
                                VStack(spacing: 12) {
                                    ForEach(tenHands.indices, id: \.self) { handIndex in
                                        HStack {
                                            Text("第 \(handIndex + 1) 手")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        LazyVGrid(columns: fiveColumns, spacing: 8) {
                                            ForEach(Array(tenHands[handIndex].enumerated()), id: \.offset) { index, drawnCard in
                                                handCardButton(drawnCard, index: handIndex * 5 + index)
                                            }
                                        }
                                    }
                                }
                                .id(drawSessionId)
                                .padding()
                            } else {
                                // 卡片网格
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(Array(cards.enumerated()), id: \.offset) { index, drawnCard in
                                        handCardButton(drawnCard, index: index)
                                    }
                                }
                                .id(drawSessionId) // 重抽时强制整个网格重建
                                .padding()
                            }

                            // +1 按钮
                            if !isTenDrawMode && nextDrawIndex < shuffledCardIds.count {
                                Button {
                                    Task {
                                        await drawOneMoreCard()
                                    }
                                } label: {
                                    Label("抽一张 (+1)", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("起手测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button("十连抽") {
                            Task {
                                await drawTenHands()
                            }
                        }

                        Button("重抽") {
                            Task {
                                await resetHand()
                            }
                        }
                    }
                }
            }
            .sheet(item: $showingCard) { card in
                NavigationView {
                    CardDetailView(card: card)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showingCard = nil
                                }
                            }
                        }
                }
            }
            .sheet(item: $showingPreReleaseCard) { card in
                NavigationView {
                    PreReleaseCardDetailView(card: card)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showingPreReleaseCard = nil
                                }
                            }
                        }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await resetHand()
        }
    }

    private var fiveColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    }

    @ViewBuilder
    private func handCardButton(_ drawnCard: DrawnCard, index: Int) -> some View {
        Button {
            switch drawnCard {
            case .normal(let card):
                showingCard = card
            case .preRelease(let card):
                showingPreReleaseCard = card
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    cardImageView(for: drawnCard, index: index)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 5)

                    // 先行卡标识
                    if drawnCard.isPreRelease {
                        Text("先行")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .offset(x: -4, y: 4)
                    }
                }

                Text(drawnCard.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    /// 构建卡图视图
    @ViewBuilder
    private func cardImageView(for drawnCard: DrawnCard, index: Int) -> some View {
        switch drawnCard {
        case .normal(let card):
            CachedAsyncImage(
                url: settings.getImageURL(for: card, size: .half),
                cacheKey: "\(settings.cardImageLanguage.rawValue)-hand-\(drawSessionId.uuidString)-\(index)-\(card.id)"
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(0.69, contentMode: .fit)
                    .overlay(ProgressView())
            }
        case .preRelease(let card):
            CachedAsyncImage(
                url: card.imageURL,
                cacheKey: "hand-prerelease-\(drawSessionId.uuidString)-\(index)-\(card.id)"
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(0.69, contentMode: .fit)
                    .overlay(ProgressView())
            }
        }
    }

    /// 重置起手
    private func resetHand() async {
        let mainDeck = deck.mainDeckCards
        guard mainDeck.count >= 5 else {
            cards = []
            shuffledCardIds = []
            nextDrawIndex = 0
            tenHands = []
            isTenDrawMode = false
            return
        }

        drawSessionId = UUID()
        shuffledCardIds = mainDeck.map(\.cardId).shuffled()
        cards = []
        nextDrawIndex = 0
        tenHands = []
        isTenDrawMode = false
        await draw(count: 5, animated: false)
    }

    /// 抽一张卡
    private func drawOneMoreCard() async {
        await draw(count: 1, animated: true)
    }

    private func draw(count: Int, animated: Bool) async {
        var remaining = count
        while remaining > 0 && nextDrawIndex < shuffledCardIds.count {
            let cardId = shuffledCardIds[nextDrawIndex]
            nextDrawIndex += 1

            // 先尝试从正式卡库获取
            if let card = CardRepository.shared.getCard(byId: cardId) {
                if animated {
                    withAnimation {
                        cards.append(.normal(card))
                    }
                } else {
                    cards.append(.normal(card))
                }
                remaining -= 1
            } else if let preRelease = await PreReleaseCardService.shared.getCard(byId: cardId) {
                // 从先行卡缓存获取
                if animated {
                    withAnimation {
                        cards.append(.preRelease(preRelease))
                    }
                } else {
                    cards.append(.preRelease(preRelease))
                }
                remaining -= 1
            }
            // 如果都找不到，跳过这张卡
        }
    }

    /// 十连抽：10次起手测试（每次5张）
    private func drawTenHands() async {
        let mainDeck = deck.mainDeckCards
        guard mainDeck.count >= 5 else {
            cards = []
            shuffledCardIds = []
            nextDrawIndex = 0
            tenHands = []
            isTenDrawMode = false
            return
        }

        isLoading = true
        drawSessionId = UUID()
        cards = []
        shuffledCardIds = []
        nextDrawIndex = 0
        isTenDrawMode = true
        tenHands = []

        let mainDeckCards = mainDeck
        for _ in 0..<10 {
            let hand = await drawHand(from: mainDeckCards, count: 5)
            tenHands.append(hand)
        }
        isLoading = false
    }

    private func drawHand(from deckCards: [DeckCardItem], count: Int) async -> [DrawnCard] {
        var result: [DrawnCard] = []
        let shuffled = deckCards.shuffled()
        var index = 0
        while result.count < count && index < shuffled.count {
            let cardId = shuffled[index].cardId
            index += 1
            if let card = CardRepository.shared.getCard(byId: cardId) {
                result.append(.normal(card))
            } else if let preRelease = await PreReleaseCardService.shared.getCard(byId: cardId) {
                result.append(.preRelease(preRelease))
            }
        }
        return result
    }
}

#Preview {
    HandTestView(deck: Deck(name: "测试卡组"))
}
