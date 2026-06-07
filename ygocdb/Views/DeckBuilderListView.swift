//
//  DeckBuilderListView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import SwiftUI
import UIKit

/// 卡组列表视图
struct DeckBuilderListView: View {
    @StateObject private var viewModel = DeckBuilderViewModel()
    @State private var showImportDeck = false
    @State private var activeNameDialog: DeckNameDialog?

    var body: some View {
        ZStack {
            Group {
                if viewModel.decks.isEmpty {
                    EmptyDeckListView {
                        activeNameDialog = .create
                    }
                } else {
                    List {
                        ForEach(viewModel.decks) { deck in
                            NavigationLink(destination: DeckBuilderView(deck: deck)) {
                                DeckRowView(deck: deck)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteDeck(deck)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    activeNameDialog = .rename(deck)
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button {
                                    activeNameDialog = .duplicate(deck)
                                } label: {
                                    Label("复制", systemImage: "doc.on.doc")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .id(viewModel.decks.isEmpty)

            if let dialog = activeNameDialog {
                deckNameDialog(dialog)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("组卡器")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadDecks()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 对战模拟按钮
                    NavigationLink {
                        DeckBattleListView()
                    } label: {
                        if #available(iOS 16.0, *) {
                            Image(systemName: "figure.fencing")
                        } else {
                            Image(systemName: "person.2.fill")
                        }
                    }
                    .accessibilityLabel("对战模拟")

                    // 导入按钮
                    Button {
                        showImportDeck = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }

                    // 创建按钮
                    Button {
                        activeNameDialog = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showImportDeck) {
            DeckImportView(viewModel: viewModel)
        }

    }

    @ViewBuilder
    private func deckNameDialog(_ dialog: DeckNameDialog) -> some View {
        switch dialog {
        case .create:
            DeckNameInputSheet(
                title: "创建卡组",
                message: "请输入新卡组的名称",
                placeholder: "卡组名称",
                initialName: "",
                confirmTitle: "创建",
                isPresented: nameDialogPresentedBinding
            ) { name in
                if !name.isEmpty {
                    viewModel.createDeck(name: name)
                }
            }
        case let .rename(deck):
            DeckNameInputSheet(
                title: "重命名卡组",
                message: "请输入新的卡组名称",
                placeholder: "卡组名称",
                initialName: deck.name,
                confirmTitle: "确定",
                isPresented: nameDialogPresentedBinding
            ) { name in
                if !name.isEmpty {
                    viewModel.renameDeck(deck, newName: name)
                }
            }
        case let .duplicate(deck):
            DeckNameInputSheet(
                title: "复制卡组",
                message: "可以调整复制后的卡组名称；不修改则使用默认名称。",
                placeholder: "卡组名称",
                initialName: "\(deck.name)-复制",
                confirmTitle: "复制",
                isPresented: nameDialogPresentedBinding
            ) { name in
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackName = "\(deck.name)-复制"
                viewModel.duplicateDeck(deck, newName: trimmedName.isEmpty ? fallbackName : trimmedName)
            }
        }
    }

    private var nameDialogPresentedBinding: Binding<Bool> {
        .init(
            get: { activeNameDialog != nil },
            set: { if !$0 { activeNameDialog = nil } }
        )
    }
}

private enum DeckNameDialog {
    case create
    case rename(Deck)
    case duplicate(Deck)
}


/// 卡组行视图
struct DeckRowView: View {
    let deck: Deck

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.headline)

            HStack(spacing: 16) {
                Label("\(deck.mainDeckCount)", systemImage: "rectangle.stack")
                    .font(.caption)
                    .foregroundColor(.blue)

                Label("\(deck.extraDeckCount)", systemImage: "square.stack.3d.up")
                    .font(.caption)
                    .foregroundColor(.purple)

                Label("\(deck.sideDeckCount)", systemImage: "square.stack")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 空卡组列表视图
struct EmptyDeckListView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("暂无卡组")
                .font(.title2)
                .fontWeight(.medium)

            Text("点击右上角 + 按钮创建第一个卡组")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onCreate()
            } label: {
                Label("创建卡组", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 卡组名称输入弹窗
struct DeckNameInputSheet: View {
    let title: String
    let message: String
    let placeholder: String
    let initialName: String
    let confirmTitle: String
    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void

    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    init(
        title: String,
        message: String,
        placeholder: String,
        initialName: String,
        confirmTitle: String,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (String) -> Void
    ) {
        self.title = title
        self.message = message
        self.placeholder = placeholder
        self.initialName = initialName
        self.confirmTitle = confirmTitle
        _isPresented = isPresented
        self.onConfirm = onConfirm
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            // 卡片主体
            VStack(spacing: 0) {
                // 标题
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                // 提示信息
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // 输入框
                TextField(placeholder, text: $name)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                Divider()

                // 按钮区域
                HStack(spacing: 0) {
                    // 取消按钮
                    Button {
                        isPresented = false
                    } label: {
                        Text("取消")
                            .font(.body)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }

                    Divider()
                        .frame(height: 44)

                    // 确认按钮
                    Button {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        isPresented = false
                        if !trimmedName.isEmpty {
                            onConfirm(trimmedName)
                        }
                    } label: {
                        Text(confirmTitle)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .blue.opacity(0.5) : .blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .onAppear {
            name = initialName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

#Preview {
    DeckBuilderListView()
}
