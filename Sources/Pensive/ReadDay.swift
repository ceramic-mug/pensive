import Foundation
import SwiftData

@Model
final class ReadDay {
    var dateString: String = "" // Format: YYYY-MM-DD
    var isRead: Bool = false
    
    init(dateString: String, isRead: Bool = true) {
        self.dateString = dateString
        self.isRead = isRead
    }
}
