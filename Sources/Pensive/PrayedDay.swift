import Foundation
import SwiftData

@Model
final class PrayedDay {
    var dateString: String = "" // Format: YYYY-MM-DD
    var isPrayed: Bool = false
    
    init(dateString: String, isPrayed: Bool = true) {
        self.dateString = dateString
        self.isPrayed = isPrayed
    }
}
