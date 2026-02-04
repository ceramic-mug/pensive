import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \JournalSection.entry) 
    var sections: [JournalSection]? = []
    
    // Kept for potential migration of old data, though we'll move it to a section
    var content: String = ""
    
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    
    var isFavorite: Bool = false
    var tags: [String] = []
    
    init(content: String = "", date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.content = content
        self.sections = []
        self.isFavorite = false
        self.tags = []
    }
}
