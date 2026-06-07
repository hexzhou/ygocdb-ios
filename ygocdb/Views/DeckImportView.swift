//
//  DeckImportView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/25.
//

import SwiftUI

/// 卡组导入视图
struct DeckImportView: View {
    @ObservedObject var viewModel: DeckBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var deckCode = ""
    @State private var deckName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var previewDeck: Deck?
    @FocusState private var focusedField: FocusField?
    
    private enum FocusField {
        case deckCode
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("卡组名称", text: $deckName)
                } header: {
                    Text("卡组名称")
                }

                Section {
                    TextEditor(text: $deckCode)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .deckCode)
                } header: {
                    Text("卡组代码")
                } footer: {
                    Text("支持 #main/#extra/!side 文本格式，或 YGOPRO2 的卡组代码")
                }

                if let preview = previewDeck {
                    Section {
                        HStack {
                            Label("主卡组", systemImage: "rectangle.stack")
                            Spacer()
                            Text("\(preview.mainDeckCount) 张")
                                .foregroundColor(.blue)
                        }

                        HStack {
                            Label("额外卡组", systemImage: "square.stack.3d.up")
                            Spacer()
                            Text("\(preview.extraDeckCount) 张")
                                .foregroundColor(.purple)
                        }

                        HStack {
                            Label("副卡组", systemImage: "square.stack")
                            Spacer()
                            Text("\(preview.sideDeckCount) 张")
                                .foregroundColor(.orange)
                        }
                    } header: {
                        Text("预览")
                    }
                }
            }
            .navigationTitle("导入卡组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导入") {
                        importDeck()
                    }
                    .disabled(deckName.isEmpty || deckCode.isEmpty)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                focusedField = nil
            })
            .modifier(DeckImportKeyboardDismissModifier())
            .onChange(of: deckCode) { newValue in
                updatePreview()
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    /// 更新预览
    private func updatePreview() {
        guard !deckCode.isEmpty else {
            previewDeck = nil
            return
        }

        previewDeck = Deck.importFromCode(deckCode, name: "预览")
    }

    /// 导入卡组
    private func importDeck() {
        guard !deckName.isEmpty else {
            errorMessage = "请输入卡组名称"
            showError = true
            return
        }

        guard !deckCode.isEmpty else {
            errorMessage = "请粘贴卡组代码"
            showError = true
            return
        }

        guard let deck = Deck.importFromCode(deckCode, name: deckName) else {
            errorMessage = "卡组代码格式错误（支持 YDK 文本或 Base64）或无有效卡片"
            showError = true
            return
        }

        do {
            try DeckService.shared.saveDeck(deck)
            viewModel.loadDecks()
            dismiss()
        } catch {
            errorMessage = "保存卡组失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

private struct DeckImportKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.immediately)
        } else {
            content
        }
    }
}

#Preview {
    DeckImportView(viewModel: DeckBuilderViewModel())
}
