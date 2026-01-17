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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 卡图
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
                .frame(maxWidth: 300)
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
                
                // 卡名和状态
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(card.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                        
                        if let label = card.statusLabel {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(card.created ? Color.red : Color.orange)
                                .cornerRadius(6)
                        }
                    }
                }
                
                Divider()
                
                // 卡片信息（与正式卡一致）
                VStack(alignment: .leading, spacing: 8) {
                    Text("卡片信息")
                        .font(.headline)
                    
                    Text(card.overallString)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // 卡片效果（与正式卡一致）
                VStack(alignment: .leading, spacing: 8) {
                    Text("效果")
                        .font(.headline)
                    
                    Text(card.desc.replacingOccurrences(of: "\\r\\n", with: "\n"))
                        .font(.body)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // 卡片密码（与正式卡一致）
                VStack(alignment: .leading, spacing: 8) {
                    Text("卡片密码")
                        .font(.headline)
                    
                    Text(String(format: "%09d", card.id))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // 更新信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("更新信息")
                        .font(.headline)
                    
                    HStack {
                        Text("创建时间:")
                            .foregroundColor(.secondary)
                        Text(card.createDateString)
                    }
                    .font(.body)
                    
                    HStack {
                        Text("更新时间:")
                            .foregroundColor(.secondary)
                        Text(card.updateDateString)
                    }
                    .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle(card.name)
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
        var info = "【\(card.name)】\n"
        info += "\(card.overallString)\n\n"
        info += "【效果】\n\(card.desc.replacingOccurrences(of: "\\r\\n", with: "\n"))"
        
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
