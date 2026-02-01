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
    @State private var showCreateDeck = false
    @State private var showImportDeck = false
    @State private var newDeckName = ""
    @State private var editingDeck: Deck?

    var body: some View {
        ZStack {
            Group {
                if viewModel.decks.isEmpty {
                    EmptyDeckListView {
                        showCreateDeck = true
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
                                    editingDeck = deck
                                    newDeckName = deck.name
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .id(viewModel.decks.isEmpty)

            if showCreateDeck {
                DeckNameInputSheet(
                    title: "创建卡组",
                    message: "请输入新卡组的名称",
                    placeholder: "卡组名称",
                    initialName: "",
                    confirmTitle: "创建",
                    useSheetBackgroundClear: false,
                    isPresented: $showCreateDeck
                ) { name in
                    if !name.isEmpty {
                        viewModel.createDeck(name: name)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("组卡器")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadDecks()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 导入按钮
                    Button {
                        showImportDeck = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }

                    // 创建按钮
                    Button {
                        showCreateDeck = true
                        newDeckName = ""
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(item: $editingDeck) { deck in
            DeckNameInputSheet(
                title: "重命名卡组",
                message: "请输入新的卡组名称",
                placeholder: "卡组名称",
                initialName: deck.name,
                confirmTitle: "确定",
                isPresented: .init(
                    get: { editingDeck != nil },
                    set: { if !$0 { editingDeck = nil } }
                )
            ) { name in
                if !name.isEmpty {
                    viewModel.renameDeck(deck, newName: name)
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

/// 卡组名称输入对话框（兼容 iOS 15，卡片式设计）
struct DeckNameInputSheet: View {
    let title: String
    let message: String
    let placeholder: String
    let initialName: String
    let confirmTitle: String
    let useSheetBackgroundClear: Bool
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
        useSheetBackgroundClear: Bool = true,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (String) -> Void
    ) {
        self.title = title
        self.message = message
        self.placeholder = placeholder
        self.initialName = initialName
        self.confirmTitle = confirmTitle
        self.useSheetBackgroundClear = useSheetBackgroundClear
        _isPresented = isPresented
        self.onConfirm = onConfirm
    }

    var body: some View {
        ZStack {
            // 透明背景（点击可收起键盘）
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击背景收起键盘
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
        .background {
            if useSheetBackgroundClear {
                SheetBackgroundClearView()
            }
        }
        .onAppear {
            name = initialName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

private struct SheetBackgroundClearView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.backgroundColor = .clear
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    DeckBuilderListView()
}
