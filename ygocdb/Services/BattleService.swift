//
//  BattleService.swift
//  ygocdb
//
//  Created by hexzhou on 2026/2/14.
//

import Foundation

/// 对战记录持久化服务
class BattleService {
    static let shared = BattleService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// 对战记录存储目录
    private var battlesDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Battles", isDirectory: true)
    }

    private init() {
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: battlesDirectory.path) {
            try? fileManager.createDirectory(at: battlesDirectory, withIntermediateDirectories: true)
        }
    }

    /// 加载所有对战会话
    func loadAllSessions() -> [BattleSession] {
        guard let files = try? fileManager.contentsOfDirectory(at: battlesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        let sessions = files.compactMap { url -> BattleSession? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let session = try? decoder.decode(BattleSession.self, from: data) else {
                return nil
            }
            return session
        }

        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 加载指定会话
    func loadSession(id: UUID) -> BattleSession? {
        let fileURL = battlesDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL),
              let session = try? decoder.decode(BattleSession.self, from: data) else {
            return nil
        }
        return session
    }

    /// 保存对战会话
    func saveSession(_ session: BattleSession) throws {
        let fileURL = battlesDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try encoder.encode(session)
        try data.write(to: fileURL)
    }

    /// 删除对战会话
    func deleteSession(_ session: BattleSession) throws {
        let fileURL = battlesDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
    }

    /// 向会话中添加一条记录
    func addRecord(_ record: BattleRecord, to sessionId: UUID) throws {
        guard var session = loadSession(id: sessionId) else { return }
        session.records.append(record)
        session.updatedAt = Date()
        try saveSession(session)
    }

    /// 删除会话中的一条记录
    func deleteRecord(recordId: UUID, from sessionId: UUID) throws {
        guard var session = loadSession(id: sessionId) else { return }
        session.records.removeAll { $0.id == recordId }
        session.updatedAt = Date()
        try saveSession(session)
    }
}
