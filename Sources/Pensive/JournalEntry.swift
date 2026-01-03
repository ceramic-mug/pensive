import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \JournalSection.entry) 
    var sections: [JournalSection] = []
    
    // Kept for potential migration of old data, though we'll move it to a section
    var content: String 
    
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    
    init(content: String = "", date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.content = content
        self.sections = []
    }
}
