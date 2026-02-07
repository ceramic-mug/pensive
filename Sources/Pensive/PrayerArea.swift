import Foundation
import SwiftData

@Model
final class PrayerArea {
    var id: UUID = UUID()
    var title: String = ""
    var icon: String = "folder"
    var order: Int = 0
    
    @Relationship(deleteRule: .cascade, inverse: \PrayerItem.area)
    var items: [PrayerItem]? = []
    
    init(title: String, icon: String = "folder", order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.order = order
        self.items = []
    }
    
    var activeItems: [PrayerItem] {
        (items ?? []).filter { !$0.isArchived }.sorted(by: { $0.dateCreated < $1.dateCreated })
    }
    
    var archivedItems: [PrayerItem] {
        (items ?? []).filter { $0.isArchived }.sorted(by: { ($0.dateArchived ?? $0.dateCreated) > ($1.dateArchived ?? $1.dateCreated) })
    }
}
