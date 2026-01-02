import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var content: String
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    
    init(content: String = "", date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.content = content
    }
}
