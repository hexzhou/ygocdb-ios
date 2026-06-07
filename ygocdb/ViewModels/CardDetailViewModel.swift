//
//  CardDetailViewModel.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/12.
//

import Foundation
import Combine
import os.log

extension Error {
    var isTaskCancellation: Bool {
        if self is CancellationError {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

/// 卡片详情视图模型
@MainActor
class CardDetailViewModel: ObservableObject {
    @Published var cardDetail: CardFullDetail?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let card: Card
    private let logger = Logger(subsystem: "com.ygocdb", category: "CardDetailViewModel")
    
    init(card: Card) {
        self.card = card
    }
    
    /// 在线模式下获取完整卡片信息
    func fetchDetailIfOnline() async {
        // 检查是否为在线模式
        guard AppSettings.shared.networkMode == .online else {
            logger.info("📴 离线模式，跳过获取卡片详情")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            cardDetail = try await YGODBService.shared.fetchCardDetail(cardId: card.id)
            logger.info("✅ 成功获取卡片详情: \(self.card.id)")
        } catch {
            if error.isTaskCancellation || Task.isCancelled {
                logger.debug("⏹️ 卡片详情请求已取消: \(self.card.id)")
                isLoading = false
                return
            }

            self.error = error.localizedDescription
            logger.error("❌ 获取卡片详情失败: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// 是否有 FAQ
    var hasFAQs: Bool {
        !(cardDetail?.faqs?.isEmpty ?? true)
    }

    /// 是否有补充调整
    var hasSupplement: Bool {
        !(cardDetail?.supplement?.cleanText.isEmpty ?? true)
    }
    
    /// 是否有日版发售信息
    var hasJPPacks: Bool {
        !(cardDetail?.jppacks?.isEmpty ?? true)
    }
    
    /// 是否有英版发售信息
    var hasENPacks: Bool {
        !(cardDetail?.enpacks?.isEmpty ?? true)
    }
}
