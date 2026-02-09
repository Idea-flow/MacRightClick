//
//  Item.swift
//  MacRightClick
//
//  Created by 王鹏龙 on 2026/2/9.
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
