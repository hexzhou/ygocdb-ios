//
//  DeckBattleListView.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/14.
//

import SwiftUI

/// 对战模拟列表页面 — 展示所有模拟组
struct DeckBattleListView: View {
    @StateObject private var viewModel = DeckBuilderViewModel()
    @State private var sessions: [BattleSession] = []
    @State private var showCreateSession = false

    private let battleService = BattleService.shared

    var body: some View {
        Group {
            if sessions.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "figure.fencing")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无对战模拟")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("点击右上角 + 新建一组模拟")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink {
                            DeckBattleView(session: session, allDecks: viewModel.decks)
                        } label: {
                            BattleSessionRow(session: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSession(session)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("对战模拟")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSession = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSession) {
            DeckBattleSetupView(decks: viewModel.decks) { deckA, deckB in
                createSession(deckA: deckA, deckB: deckB)
            }
        }
        .onAppear {
            loadSessions()
        }
    }

    private func loadSessions() {
        sessions = battleService.loadAllSessions()
    }

    private func createSession(deckA: Deck, deckB: Deck) {
        let session = BattleSession(
            deckAId: deckA.id,
            deckBId: deckB.id,
            deckAName: deckA.name,
            deckBName: deckB.name
        )
        try? battleService.saveSession(session)
        loadSessions()
    }

    private func deleteSession(_ session: BattleSession) {
        try? battleService.deleteSession(session)
        sessions.removeAll { $0.id == session.id }
    }
}

/// 模拟组行视图
struct BattleSessionRow: View {
    let session: BattleSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 对战双方
            HStack(spacing: 6) {
                Circle().fill(Color.blue).frame(width: 6, height: 6)
                Text(session.deckAName)
                    .font(.subheadline)
                    .lineLimit(1)

                Text("vs")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Circle().fill(Color.red).frame(width: 6, height: 6)
                Text(session.deckBName)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            // 统计信息
            HStack(spacing: 12) {
                Label("\(session.records.count) 组", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if session.totalMarkedRounds > 0 {
                    Text("\(session.totalAWins):\(session.totalBWins)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatDate(session.updatedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
