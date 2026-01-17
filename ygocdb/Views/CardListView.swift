//
//  CardListView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

/// 卡片列表视图
struct CardListView: View {
    let cards: [Card]
    @ObservedObject var settings = AppSettings.shared
    @State private var toastMessage: String?
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List(cards) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        CardRowView(card: card)
                    }
                    .contextMenu {
                        Button {
                            copyCardInfo(card)
                        } label: {
                            Label("复制卡片信息", systemImage: "doc.on.doc")
                        }
                    }
                    .id(card.id)
                }
                .listStyle(PlainListStyle())
                .onChange(of: cards.first?.id) { _ in
                    // 当卡片列表变化时滚动到顶部
                    if let firstCard = cards.first {
                        withAnimation {
                            proxy.scrollTo(firstCard.id, anchor: .top)
                        }
                    }
                }
            }
            
            // Toast 提示
            if let message = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .padding(.bottom, 50)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: toastMessage)
            }
        }
    }
    
    /// 复制卡片信息到剪贴板
    private func copyCardInfo(_ card: Card) {
        let displayName = settings.getDisplayName(for: card)
        var info = "【\(displayName)】\n"
        info += "\(card.typesDisplay)\n\n"
        
        if !card.pdescDisplay.isEmpty {
            info += "【灵摆效果】\n\(card.pdescDisplay)\n\n"
        }
        
        info += "【效果】\n\(card.descDisplay)"
        
        UIPasteboard.general.string = info
        
        // 显示 Toast
        withAnimation {
            toastMessage = "\(displayName) 复制成功"
        }
        
        // 1.5秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

/// Toast 提示视图
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 5)
    }
}

#Preview {
    NavigationView {
        CardListView(cards: [])
    }
}
