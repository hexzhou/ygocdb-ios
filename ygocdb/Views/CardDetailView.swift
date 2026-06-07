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
    @State private var showFullImage = false

    init(card: Card) {
        self.card = card
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(card: card))
    }

    private var hasOnlineSections: Bool {
        settings.networkMode == .online && (
            viewModel.isLoading ||
            viewModel.hasSupplement ||
            viewModel.hasFAQs ||
            viewModel.hasJPPacks ||
            viewModel.hasENPacks
        )
    }

    private var formattedOtDisplay: String {
        card.otDisplay.replacingOccurrences(of: "|", with: " | ")
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    topSummarySection(availableWidth: max(geometry.size.width - 32, 0))

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

                    // 在线模式额外信息
                    if hasOnlineSections {
                        Divider()

                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("加载更多信息...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            Divider()
                        }

                        // 补充调整
                        if viewModel.hasSupplement, let supplement = viewModel.cardDetail?.supplement {
                            SupplementSection(supplement: supplement)
                            Divider()
                        }

                        // FAQ 区域
                        if viewModel.hasFAQs, let faqs = viewModel.cardDetail?.faqs {
                            FAQSection(faqs: faqs)
                            Divider()
                        }

                        // 发售信息区域
                        if viewModel.hasJPPacks || viewModel.hasENPacks {
                            PacksSection(
                                jppacks: viewModel.cardDetail?.jppacks,
                                enpacks: viewModel.cardDetail?.enpacks
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(settings.getDisplayName(for: card))
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
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
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageView(
                url: settings.getImageURL(for: card, size: .full),
                cacheKey: "\(settings.cardImageLanguage.rawValue)-\(card.id)-full",
                initialImage: loadedImage
            )
        }
    }

    private func topSummarySection(availableWidth: CGFloat) -> some View {
        let imageWidth: CGFloat
        let spacing: CGFloat

        switch availableWidth {
        case ..<360:
            imageWidth = 118
            spacing = 12
        case ..<430:
            imageWidth = 132
            spacing = 14
        case ..<560:
            imageWidth = 144
            spacing = 16
        default:
            imageWidth = min(max(availableWidth * 0.30, 148), 180)
            spacing = 18
        }

        return HStack(alignment: .top, spacing: spacing) {
            detailImage(width: imageWidth)
            cardInfoSection
        }
    }

    private func detailImage(width: CGFloat) -> some View {
        CachedAsyncImage(
            url: settings.getImageURL(for: card, size: settings.detailImageQuality.size),
            cacheKey: "\(settings.cardImageLanguage.rawValue)-\(card.id)-\(settings.detailImageQuality.rawValue)"
        ) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(radius: 10)
                .onAppear {
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
        .frame(width: width)
        .contentShape(Rectangle())
        .onTapGesture {
            showFullImage = true
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
                .padding(6)
        }
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
    }

    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.getDisplayName(for: card))
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let jpName = card.jpName {
                Text(jpName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let enName = card.enName {
                Text(enName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(card.typesDisplay)
                .font(.subheadline)
                .foregroundColor(.blue)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                metaRow(label: "卡密", value: String(format: "%08d", card.id), monospaced: true)
                metaRow(label: "CID", value: String(card.cid), monospaced: true)
                metaRow(label: "范围", value: formattedOtDisplay)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .leading)

            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
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

/// 补充调整区域视图
struct SupplementSection: View {
    let supplement: CardSupplement
    @State private var showCopiedToast = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                    Text("补充调整")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                if let date = supplement.date {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(supplement.cleanText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button {
                        copySupplement()
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
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copySupplement() {
        let text = supplement.cleanText
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
                    HStack(spacing: 12) {
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

/// 全屏查看大卡图
struct FullImageView: View {
    let url: URL?
    let cacheKey: String
    let initialImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSavedToast = false

    private var actionImage: UIImage? {
        loadedImage ?? initialImage
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            CachedAsyncImage(url: url, cacheKey: cacheKey) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                if actionImage != nil {
                    Button {
                        saveImageToPhotos()
                    } label: {
                        Label("保存到相册", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }

            if showSavedToast {
                VStack {
                    Spacer()
                    Text("已保存到相册")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .task(id: url?.absoluteString) {
            guard let url = url else { return }
            if let cachedImage = await ImageCache.shared.loadImage(for: url) {
                loadedImage = cachedImage
                return
            }
            loadedImage = try? await ImageCache.shared.downloadAndCache(from: url)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = actionImage {
                ShareSheet(items: [image])
            }
        }
    }

    private func saveImageToPhotos() {
        guard let image = actionImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
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
