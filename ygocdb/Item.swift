//
//  Item.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
