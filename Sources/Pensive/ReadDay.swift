import Foundation
import SwiftData

@Model
final class ReadDay {
    @Attribute(.unique) var dateString: String // Format: YYYY-MM-DD
    var isRead: Bool
    
    init(dateString: String, isRead: Bool = true) {
        self.dateString = dateString
        self.isRead = isRead
    }
}
