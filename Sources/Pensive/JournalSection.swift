import Foundation
import SwiftData

@Model
final class JournalSection {
    var id: UUID
    var title: String
    var content: String
    var timestamp: Date
    var entry: JournalEntry?
    
    init(content: String = "", title: String = "", timestamp: Date = .now) {
        self.id = UUID()
        self.content = content
        self.title = title
        self.timestamp = timestamp
    }
}
