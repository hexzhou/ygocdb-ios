//
//  CardDetailView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

/// 卡片详情视图
struct CardDetailView: View {
    let card: Card
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var viewModel: CardDetailViewModel
    @State private var toastMessage: String?
    @State private var loadedImage: UIImage?
    @State private var showShareSheet = false
    
    init(card: Card) {
        self.card = card
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(card: card))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 卡图（带缓存）
                CachedAsyncImage(
                    url: settings.getImageURL(for: card, size: settings.detailImageQuality.size),
                    cacheKey: "\(settings.cardImageLanguage.rawValue)-\(card.id)-\(settings.detailImageQuality.rawValue)"
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(radius: 10)
                        .onAppear {
                            // 保存加载的图片用于分享/保存
                            Task {
                                if let url = settings.getImageURL(for: card, size: settings.detailImageQuality.size) {
                                    loadedImage = try? await ImageCache.shared.downloadAndCache(from: url)
                                }
                            }
                        }
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(0.69, contentMode: .fit)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(maxWidth: settings.detailImageQuality == .original ? 400 : 250)
                .contextMenu {
                    Button {
                        saveImageToAlbum()
                    } label: {
                        Label("保存到相册", systemImage: "square.and.arrow.down")
                    }
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("分享图片", systemImage: "square.and.arrow.up")
                    }
                }
                
                // 卡片名称
                VStack(spacing: 8) {
                    Text(settings.getDisplayName(for: card))
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    
                    if let jpName = card.jpName {
                        Text(jpName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    if let enName = card.enName {
                        Text(enName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                Divider()
                
                // 卡片类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("卡片信息")
                        .font(.headline)
                    
                    Text(card.typesDisplay)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // 灵摆效果（如果有）
                if !card.pdescDisplay.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("灵摆效果")
                            .font(.headline)
                        
                        Text(card.pdescDisplay)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                }
                
                // 卡片效果/描述
                VStack(alignment: .leading, spacing: 8) {
                    Text((card.data?.isMonster ?? false) ? "效果/描述" : "效果")
                        .font(.headline)
                    
                    Text(card.descDisplay)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // 卡片密码
                VStack(alignment: .leading, spacing: 4) {
                    Text("卡片密码")
                        .font(.headline)
                    
                    Text(String(format: "%08d", card.id))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 在线模式额外信息
                if settings.networkMode == .online {
                    if viewModel.isLoading {
                        Divider()
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("加载更多信息...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // FAQ 区域
                    if viewModel.hasFAQs, let faqs = viewModel.cardDetail?.faqs {
                        Divider()
                        FAQSection(faqs: faqs)
                    }
                    
                    // 发售信息区域
                    if viewModel.hasJPPacks || viewModel.hasENPacks {
                        Divider()
                        PacksSection(
                            jppacks: viewModel.cardDetail?.jppacks,
                            enpacks: viewModel.cardDetail?.enpacks
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(settings.getDisplayName(for: card))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    copyCardInfo()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        .task {
            await viewModel.fetchDetailIfOnline()
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
        .sheet(isPresented: $showShareSheet) {
            if let image = loadedImage,
               let jpegData = image.jpegData(compressionQuality: 0.95),
               let jpegImage = UIImage(data: jpegData) {
                ShareSheet(items: [jpegImage])
            }
        }
    }
    
    /// 复制卡片信息
    private func copyCardInfo() {
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
    
    /// 保存图片到相册
    private func saveImageToAlbum() {
        guard let image = loadedImage else {
            showToast("图片未加载完成")
            return
        }
        
        // 将图片转换为 JPEG 格式（WebP 不支持直接保存）
        guard let jpegData = image.jpegData(compressionQuality: 0.95),
              let jpegImage = UIImage(data: jpegData) else {
            showToast("图片转换失败")
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(jpegImage, nil, nil, nil)
        showToast("已保存到相册")
    }
    
    /// 显示 Toast 提示
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

/// 分享 Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// FAQ 区域视图
struct FAQSection: View {
    let faqs: [CardQA]
    @State private var expandedFAQs: Set<String> = []
    @State private var showAllFAQs: Bool = false
    
    private var displayedFAQs: [CardQA] {
        showAllFAQs ? faqs : Array(faqs.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                Text("FAQ (\(faqs.count))")
                    .font(.headline)
            }
            
            ForEach(displayedFAQs) { faq in
                FAQItem(
                    faq: faq,
                    isExpanded: expandedFAQs.contains(faq.id),
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedFAQs.contains(faq.id) {
                                expandedFAQs.remove(faq.id)
                            } else {
                                expandedFAQs.insert(faq.id)
                            }
                        }
                    }
                )
            }
            
            // 显示更多/收起按钮
            if faqs.count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAllFAQs.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllFAQs ? "收起" : "显示全部 \(faqs.count) 条")
                            .font(.subheadline)
                        Image(systemName: showAllFAQs ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 单个 FAQ 项目
struct FAQItem: View {
    let faq: CardQA
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var showCopiedToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(alignment: .top) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(faq.cleanTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if let date = faq.date {
                            Text(date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Q: \(faq.cleanQuestion)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    
                    Text("A: \(faq.cleanAnswer)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    // 复制按钮
                    Button {
                        copyFAQ()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            Text(showCopiedToast ? "已复制" : "复制")
                        }
                        .font(.caption)
                        .foregroundColor(showCopiedToast ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func copyFAQ() {
        let text = """
        【\(faq.cleanTitle)】
        Q: \(faq.cleanQuestion)
        A: \(faq.cleanAnswer)
        """
        UIPasteboard.general.string = text
        
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}

/// 发售信息区域视图
struct PacksSection: View {
    let jppacks: [CardPack]?
    let enpacks: [CardPack]?
    @State private var showAllJPPacks: Bool = false
    @State private var showAllENPacks: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.orange)
                Text("发售信息")
                    .font(.headline)
            }
            
            // 日文版发售信息
            if let jppacks = jppacks, !jppacks.isEmpty {
                Text("🇯🇵 日文 (\(jppacks.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                let displayedJP = showAllJPPacks ? jppacks : Array(jppacks.prefix(3))
                ForEach(displayedJP) { pack in
                    PackItem(pack: pack)
                }
                
                if jppacks.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllJPPacks.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showAllJPPacks ? "收起" : "显示全部 \(jppacks.count) 个")
                                .font(.caption)
                            Image(systemName: showAllJPPacks ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            // 英文版发售信息
            if let enpacks = enpacks, !enpacks.isEmpty {
                Text("🇺🇸 英文 (\(enpacks.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                let displayedEN = showAllENPacks ? enpacks : Array(enpacks.prefix(3))
                ForEach(displayedEN) { pack in
                    PackItem(pack: pack)
                }
                
                if enpacks.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllENPacks.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showAllENPacks ? "收起" : "显示全部 \(enpacks.count) 个")
                                .font(.caption)
                            Image(systemName: showAllENPacks ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 单个卡包信息
struct PackItem: View {
    let pack: CardPack
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.caption)
                    .lineLimit(2)
                    .textSelection(.enabled)
                
                if let setid = pack.setid {
                    Text(setid)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
            }
            
            Spacer()
            
            Text(pack.date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationView {
        CardDetailView(card: Card(
            cid: 4007,
            id: 89631139,
            cnName: "青眼白龙",
            scName: "青眼白龙",
            mdName: nil,
            nwbbsN: nil,
            cnocgN: nil,
            jpRuby: "ブルーアイズ・ホワイト・ドラゴン",
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
