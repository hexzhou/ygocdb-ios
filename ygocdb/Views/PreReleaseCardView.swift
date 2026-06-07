//
//  PreReleaseCardView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/13.
//

import SwiftUI

/// 先行卡列表视图
struct PreReleaseCardListView: View {
    @StateObject private var viewModel = PreReleaseCardViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.cards.isEmpty {
                    ProgressView("加载先行卡...")
                } else if viewModel.cards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("暂无先行卡数据")
                            .font(.title2)
                        
                        Button("重新加载") {
                            Task { await viewModel.refresh() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List(viewModel.filteredCards) { card in
                        NavigationLink(destination: PreReleaseCardDetailView(card: card)) {
                            PreReleaseCardRowView(card: card)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("先行卡")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索先行卡...")
            .task {
                await viewModel.loadCards()
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// 先行卡行视图
struct PreReleaseCardRowView: View {
    let card: PreReleaseCard
    
    var body: some View {
        HStack(spacing: 12) {
            // 卡图
            CachedAsyncImage(
                url: card.imageURL,
                cacheKey: "pre-\(card.id)"
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
                HStack {
                    Text(card.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // 状态标签
                    if let label = card.statusLabel {
                        Text(label)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(card.created ? Color.red : Color.orange)
                            .cornerRadius(4)
                    }
                }
                
                Text(card.overallString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// 先行卡详情视图
struct PreReleaseCardDetailView: View {
    let card: PreReleaseCard
    @State private var toastMessage: String?
    @State private var loadedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showFullImage = false

    private var normalizedDesc: String {
        card.desc.replacingOccurrences(of: "\\r\\n", with: "\n")
    }

    private var statusColor: Color {
        card.created ? .red : .orange
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    topSummarySection(availableWidth: max(geometry.size.width - 32, 0))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("效果")
                            .font(.headline)

                        Text(normalizedDesc)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
        .navigationTitle(card.name)
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
                url: card.imageURL,
                cacheKey: "pre-\(card.id)-full",
                initialImage: loadedImage
            )
        }
    }

    @ViewBuilder
    private func topSummarySection(availableWidth: CGFloat) -> some View {
        let imageWidth = min(max(availableWidth * 0.42, 150), 220)

        if availableWidth < 520 {
            VStack(alignment: .leading, spacing: 16) {
                detailImage(width: imageWidth)
                    .frame(maxWidth: .infinity, alignment: .center)

                cardInfoSection
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        } else {
            HStack(alignment: .top, spacing: 16) {
                detailImage(width: min(imageWidth, 180))
                cardInfoSection
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    private func detailImage(width: CGFloat) -> some View {
        CachedAsyncImage(
            url: card.imageURL,
            cacheKey: "pre-\(card.id)-detail"
        ) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(radius: 10)
                .onAppear {
                    Task {
                        if let url = card.imageURL {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(card.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                Spacer(minLength: 0)

                if let label = card.statusLabel {
                    Text(label)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor)
                        .cornerRadius(6)
                }
            }

            Text(card.overallString)
                .font(.subheadline)
                .foregroundColor(.blue)
                .textSelection(.enabled)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                metaRow(label: "卡密", value: String(format: "%09d", card.id), monospaced: true)
                metaRow(label: "创建", value: card.createDateString)
                metaRow(label: "更新", value: card.updateDateString)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)

            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// 复制卡片信息
    private func copyCardInfo() {
        var info = "【\(card.name)】\n"
        info += "\(card.overallString)\n\n"
        info += "【效果】\n\(normalizedDesc)"
        
        UIPasteboard.general.string = info
        showToast("\(card.name) 复制成功")
    }
    
    /// 保存图片到相册
    private func saveImageToAlbum() {
        guard let image = loadedImage else {
            showToast("图片未加载完成")
            return
        }
        
        guard let jpegData = image.jpegData(compressionQuality: 0.95),
              let jpegImage = UIImage(data: jpegData) else {
            showToast("图片转换失败")
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(jpegImage, nil, nil, nil)
        showToast("已保存到相册")
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
}

#Preview {
    PreReleaseCardListView()
}
