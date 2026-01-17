//
//  YGODBService.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import Compression
import os.log

/// ygocdb API 服务
actor YGODBService {
    static let shared = YGODBService()
    
    private let baseURL = "https://ygocdb.com/api/v0"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.ygocdb", category: "YGODBService")
    
    private init() {
        // 使用共享的网络配置（长任务超时）
        self.session = NetworkConfig.longTask
    }
    
    /// 下载卡片数据的 MD5 校验值
    func fetchMD5() async throws -> String {
        let url = URL(string: "\(baseURL)/cards.zip.md5")!
        logger.info("📥 正在获取 MD5: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("📥 MD5 响应状态码: \(httpResponse.statusCode)")
        }
        
        guard let md5 = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            logger.error("❌ MD5 解析失败")
            throw YGODBError.invalidResponse
        }
        
        logger.info("✅ MD5: \(md5)")
        return md5
    }
    
    /// 下载并解压全卡数据
    func downloadCards(progressHandler: @escaping @Sendable (Double) -> Void) async throws -> CardDatabase {
        let url = URL(string: "\(baseURL)/cards.zip")!
        logger.info("📥 开始下载: \(url.absoluteString)")
        
        // 下载 zip 文件
        let (asyncBytes, response) = try await session.bytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ 无效的 HTTP 响应")
            throw YGODBError.downloadFailed
        }
        
        logger.info("📥 HTTP 状态码: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            logger.error("❌ HTTP 错误: \(httpResponse.statusCode)")
            throw YGODBError.downloadFailed
        }
        
        let contentLength = response.expectedContentLength
        logger.info("📥 预期大小: \(contentLength) 字节")
        
        var downloadedData = Data()
        var downloadedBytes: Int64 = 0
        
        for try await byte in asyncBytes {
            downloadedData.append(byte)
            downloadedBytes += 1
            
            if contentLength > 0 && downloadedBytes % 50000 == 0 {
                let progress = Double(downloadedBytes) / Double(contentLength)
                progressHandler(min(progress, 1.0))
                logger.debug("📥 下载进度: \(Int(progress * 100))% (\(downloadedBytes)/\(contentLength))")
            }
        }
        
        progressHandler(1.0)
        logger.info("✅ 下载完成: \(downloadedData.count) 字节")
        
        // 解压 zip 文件并解析 JSON
        return try await unzipAndParseCards(zipData: downloadedData)
    }
    
    /// 解压 zip 并解析卡片 JSON
    private func unzipAndParseCards(zipData: Data) async throws -> CardDatabase {
        logger.info("📦 开始解压 ZIP 文件...")
        
        // 查找 zip 文件中的 cards.json
        guard let jsonData = try extractCardsJSON(from: zipData) else {
            logger.error("❌ 未找到 cards.json")
            throw YGODBError.parseError
        }
        
        logger.info("✅ 提取 JSON 成功: \(jsonData.count) 字节")
        
        // 打印 JSON 前 500 个字符用于调试
        if let jsonString = String(data: jsonData.prefix(500), encoding: .utf8) {
            logger.info("📄 JSON 预览: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        
        do {
            let cards = try decoder.decode(CardDatabase.self, from: jsonData)
            logger.info("✅ 解析成功: \(cards.count) 张卡片")
            return cards
        } catch let decodingError as DecodingError {
            // 详细的解码错误信息
            switch decodingError {
            case .keyNotFound(let key, let context):
                logger.error("❌ 缺少字段: \(key.stringValue), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .typeMismatch(let type, let context):
                logger.error("❌ 类型不匹配: 期望 \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                logger.error("❌ 值缺失: 期望 \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                logger.error("❌ 数据损坏: \(context.debugDescription)")
            @unknown default:
                logger.error("❌ 未知解码错误: \(decodingError.localizedDescription)")
            }
            throw decodingError
        }
    }
    
    /// 从 zip 数据中提取 cards.json
    private func extractCardsJSON(from zipData: Data) throws -> Data? {
        logger.info("📦 ZIP 文件大小: \(zipData.count) 字节")
        
        // ZIP 文件格式解析
        // Local file header signature: 0x04034b50
        guard zipData.count > 30 else {
            logger.error("❌ ZIP 文件太小")
            return nil
        }
        
        var offset = 0
        var fileIndex = 0
        
        while offset < zipData.count - 30 {
            // 检查本地文件头签名
            let signature = zipData.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
            
            guard signature == 0x04034b50 else {
                logger.info("📦 文件头结束于偏移: \(offset)")
                break
            }
            
            // 解析本地文件头
            let compressionMethod = zipData.subdata(in: offset+8..<offset+10).withUnsafeBytes { $0.load(as: UInt16.self) }
            let compressedSize = Int(zipData.subdata(in: offset+18..<offset+22).withUnsafeBytes { $0.load(as: UInt32.self) })
            let uncompressedSize = Int(zipData.subdata(in: offset+22..<offset+26).withUnsafeBytes { $0.load(as: UInt32.self) })
            let fileNameLength = Int(zipData.subdata(in: offset+26..<offset+28).withUnsafeBytes { $0.load(as: UInt16.self) })
            let extraFieldLength = Int(zipData.subdata(in: offset+28..<offset+30).withUnsafeBytes { $0.load(as: UInt16.self) })
            
            // 获取文件名
            let fileNameData = zipData.subdata(in: offset+30..<offset+30+fileNameLength)
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
            
            logger.info("📦 文件[\(fileIndex)]: \(fileName), 压缩方法: \(compressionMethod), 压缩大小: \(compressedSize), 原始大小: \(uncompressedSize)")
            
            // 数据起始位置
            let dataOffset = offset + 30 + fileNameLength + extraFieldLength
            
            // 如果是 cards.json，解压并返回
            if fileName == "cards.json" {
                logger.info("✅ 找到 cards.json")
                let compressedData = zipData.subdata(in: dataOffset..<dataOffset+compressedSize)
                
                if compressionMethod == 0 {
                    // 无压缩
                    logger.info("📦 无压缩，直接返回")
                    return compressedData
                } else if compressionMethod == 8 {
                    // Deflate 压缩
                    logger.info("📦 使用 Deflate 解压...")
                    return try decompressDeflate(data: compressedData, uncompressedSize: uncompressedSize)
                } else {
                    logger.error("❌ 不支持的压缩方法: \(compressionMethod)")
                    return nil
                }
            }
            
            // 移动到下一个文件
            offset = dataOffset + compressedSize
            fileIndex += 1
        }
        
        logger.error("❌ 未在 ZIP 中找到 cards.json")
        return nil
    }
    
    /// Deflate 解压
    private func decompressDeflate(data: Data, uncompressedSize: Int) throws -> Data {
        logger.info("📦 解压: 输入 \(data.count) 字节, 期望输出 \(uncompressedSize) 字节")
        
        var uncompressedData = Data(count: uncompressedSize)
        
        let result = uncompressedData.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { sourceBuffer in
                compression_decode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        logger.info("📦 解压结果: \(result) 字节")
        
        guard result > 0 else {
            logger.error("❌ 解压失败, 返回值: \(result)")
            throw YGODBError.decompressFailed
        }
        
        return uncompressedData
    }
    
    // MARK: - 更新检查
    
    /// 使用 HEAD 请求检查是否有新资源
    /// - Returns: 新的 MD5 值（如果有更新）或 nil（如果无更新或检查失败）
    func checkForNewResource(localMD5: String?) async throws -> String? {
        let remoteMD5 = try await fetchMD5()
        
        if remoteMD5 != localMD5 {
//            logger.info("🔄 发现新版本: \(remoteMD5)")
            return remoteMD5
        } else {
//            logger.info("✅ 已是最新版本")
            return nil
        }
    }
    
    // MARK: - 卡片详情
    
    /// 获取单张卡片的完整信息（包含 FAQ 和发售信息）
    func fetchCardDetail(cardId: Int) async throws -> CardFullDetail {
        let url = URL(string: "\(baseURL)/card/\(cardId)?show=all")!
//        logger.info("📥 获取卡片详情: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
//            logger.error("❌ 获取卡片详情失败")
            throw YGODBError.downloadFailed
        }
        
        let decoder = JSONDecoder()
        do {
            let detail = try decoder.decode(CardFullDetail.self, from: data)
//            logger.info("✅ 获取卡片详情成功: \(detail.cnName ?? detail.jpName ?? "Unknown")")
            return detail
        } catch {
//            logger.error("❌ 解析卡片详情失败: \(error.localizedDescription)")
            throw YGODBError.parseError
        }
    }
}

/// ygocdb API 错误类型
enum YGODBError: Error, LocalizedError {
    case invalidResponse
    case downloadFailed
    case parseError
    case decompressFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .downloadFailed:
            return "下载失败"
        case .parseError:
            return "数据解析失败"
        case .decompressFailed:
            return "解压缩失败"
        }
    }
}
