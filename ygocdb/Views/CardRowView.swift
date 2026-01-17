//
//  CardRowView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

/// 卡片列表项视图
struct CardRowView: View {
    let card: Card
    
    // 直接读取设置，不需要在 row 级别订阅变化
    private var settings: AppSettings { AppSettings.shared }
    
    var body: some View {
        switch settings.cardListStyle {
        case .compact:
            CompactCardRow(card: card)
        case .detailed:
            DetailedCardRow(card: card)
        }
    }
}

/// 简洁样式
struct CompactCardRow: View {
    let card: Card
    
    private var settings: AppSettings { AppSettings.shared }
    
    var body: some View {
        HStack(spacing: 12) {
            // 卡图缩略图
            CachedAsyncImage(
                url: settings.getImageURL(for: card, size: .thumb2),
                cacheKey: "\(settings.cardImageLanguage.rawValue)-\(card.id)-thumb2"
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(width: 60, height: 87)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // 卡片信息
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.getDisplayName(for: card))
                    .font(.headline)
                    .lineLimit(1)
                
                // 卡片信息（类型、星级、攻防等）
                Text(card.typesDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// 详细样式
struct DetailedCardRow: View {
    let card: Card
    
    private var settings: AppSettings { AppSettings.shared }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：卡图、卡片名称、卡密
            HStack(spacing: 10) {
                // 卡图缩略图
                CachedAsyncImage(
                    url: settings.getImageURL(for: card, size: .thumb2),
                    cacheKey: "\(settings.cardImageLanguage.rawValue)-\(card.id)-thumb2"
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                
                // 卡片名称
                Text(settings.getDisplayName(for: card))
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // 卡密
                Text(String(format: "%08d", card.id))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            // 第二行：卡片信息（类型、星级、攻防等）
            Text(card.typesDisplay)
                .font(.caption)
                .foregroundColor(.blue)
            
            // 灵摆效果（如果有）
            if !card.pdescDisplay.isEmpty {
                Text("【灵摆效果】\(card.pdescDisplay)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 卡片效果
            Text(card.descDisplay)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        CardRowView(card: Card(
            cid: 4007,
            id: 89631139,
            cnName: "青眼白龙",
            scName: "青眼白龙",
            mdName: nil,
            nwbbsN: nil,
            cnocgN: nil,
            jpRuby: nil,
            jpName: "青眼の白龍",
            enName: "Blue-Eyes White Dragon",
            text: CardText(
                types: "[怪兽|通常] 龙/光\n[★8] 3000/2500",
                pdesc: "",
                desc: "以高攻击力著称的传说之龙。任何对手都能粉碎，其破坏力不可估量。"
            ),
            data: CardData(
                ot: 11,
                setcode: 221,
                type: 17,
                atk: 3000,
                def: 2500,
                level: 8,
                race: 8192,
                attribute: 16
            )
        ))
    }
}
