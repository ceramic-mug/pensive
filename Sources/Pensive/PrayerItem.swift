import Foundation
import SwiftData

@Model
final class PrayerItem {
    var id: UUID = UUID()
    var content: String = ""
    var dateCreated: Date = Date()
    var dateArchived: Date?
    var isArchived: Bool = false
    
    var area: PrayerArea?
    
    init(content: String = "", dateCreated: Date = .now) {
        self.id = UUID()
        self.content = content
        self.dateCreated = dateCreated
        self.isArchived = false
    }
    
    func archive() {
        self.isArchived = true
        self.dateArchived = Date()
    }
}
