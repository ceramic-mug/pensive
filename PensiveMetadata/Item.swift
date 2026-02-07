//
//  Item.swift
//  Pensive
//
//  Created by Joshua Eastman on 2/6/26.
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
