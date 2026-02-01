//
//  DeckCardGridSection.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import SwiftUI

/// 卡组网格区域视图
struct DeckCardGridSection: View {
    let items: [DeckCardItem]
    let deckType: DeckType
    let onAdd: (Int) -> Void
    let onRemove: (UUID) -> Void
    let onMoveToSide: (UUID, Int) -> Void
    let onMoveToMain: (UUID, Int) -> Void
    let onMoveToExtra: (UUID, Int) -> Void

    @State private var selectedCard: Card?
    @State private var selectedPreReleaseCard: PreReleaseCard?
    @State private var showMissingDataAlert = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    init(
        items: [DeckCardItem],
        deckType: DeckType,
        onAdd: @escaping (Int) -> Void,
        onRemove: @escaping (UUID) -> Void,
        onMoveToSide: @escaping (UUID, Int) -> Void = { _, _ in },
        onMoveToMain: @escaping (UUID, Int) -> Void = { _, _ in },
        onMoveToExtra: @escaping (UUID, Int) -> Void = { _, _ in }
    ) {
        self.items = items
        self.deckType = deckType
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onMoveToSide = onMoveToSide
        self.onMoveToMain = onMoveToMain
        self.onMoveToExtra = onMoveToExtra
        _selectedCard = State(initialValue: nil)
        _selectedPreReleaseCard = State(initialValue: nil)
        _showMissingDataAlert = State(initialValue: false)
    }

    var body: some View {
        let sortedItems = items.sorted {
            if $0.cardId == $1.cardId {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.cardId < $1.cardId
        }
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(sortedItems) { item in
                let cardId = item.cardId
                let itemId = item.id
                CardGridItem(
                    cardId: cardId,
                    onTap: { card in
                        selectedCard = card
                    },
                    onPreReleaseTap: { preRelease in
                        selectedPreReleaseCard = preRelease
                    },
                    onMissingData: {
                        showMissingDataAlert = true
                    }
                )
                .id(itemId)
                .contextMenu {
                    Button {
                        onAdd(cardId)
                    } label: {
                        Label("添加一张", systemImage: "plus.circle")
                    }

                    if deckType == .main || deckType == .extra {
                        Button {
                            onMoveToSide(itemId, cardId)
                        } label: {
                            Label("移到副卡组", systemImage: "arrow.left.arrow.right")
                        }
                    } else if deckType == .side {
                        if isExtraDeckCard(cardId) {
                            Button {
                                onMoveToExtra(itemId, cardId)
                            } label: {
                                Label("移到额外卡组", systemImage: "square.stack.3d.up")
                            }
                        } else {
                            Button {
                                onMoveToMain(itemId, cardId)
                            } label: {
                                Label("移到主卡组", systemImage: "rectangle.stack")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        onRemove(itemId)
                    } label: {
                        Label("移除一张", systemImage: "minus.circle")
                    }
                }
            }
        }
        .padding(.horizontal)
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

/// 单个卡片网格项
struct CardGridItem: View {
    let cardId: Int
    let onTap: (Card) -> Void
    let onPreReleaseTap: (PreReleaseCard) -> Void
    let onMissingData: () -> Void

    @State private var preReleaseCard: PreReleaseCard?
    @ObservedObject private var settings = AppSettings.shared

    var card: Card? {
        CardRepository.shared.getCard(byId: cardId)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let card = card {
                CachedAsyncImage(
                    url: settings.getImageURL(for: card, size: .thumb2),
                    cacheKey: "grid-\(cardId)"
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
                .clipShape(RoundedRectangle(cornerRadius: 2))
            } else if let preRelease = preReleaseCard {
                CachedAsyncImage(
                    url: preRelease.imageURL,
                    cacheKey: "grid-prerelease-\(cardId)"
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
                .clipShape(RoundedRectangle(cornerRadius: 2))

                // 先行卡小标识
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .offset(x: -2, y: 2)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(0.69, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .onTapGesture {
            if let card = card {
                onTap(card)
            } else if let preRelease = preReleaseCard {
                onPreReleaseTap(preRelease)
            } else {
                onMissingData()
            }
        }
        .task(id: cardId) {
            preReleaseCard = nil
            // 如果正式卡找不到，尝试从先行卡获取
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
}

#Preview {
    DeckCardGridSection(
        items: [],
        deckType: .main,
        onAdd: { _ in },
        onRemove: { _ in }
    )
}
