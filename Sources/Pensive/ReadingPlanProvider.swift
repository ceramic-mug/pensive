import Foundation

struct DailyReading: Identifiable {
    let id = UUID()
    let passages: [String]
    let date: Date
}

class ReadingPlanProvider {
    static let shared = ReadingPlanProvider()
    
    private var plan: [String: ReadingEntry] = [:]
    
    struct ReadingEntry: Codable {
        let family: [String]
        let secret: [String]
    }
    
    init() {
        loadPlan()
    }
    
    private func loadPlan() {
        guard let url = Bundle.main.url(forResource: "plan", withExtension: "json") else {
            print("Failed to find plan.json in main bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            plan = try JSONDecoder().decode([String: ReadingEntry].self, from: data)
        } catch {
            print("Failed to load/decode plan.json: \(error)")
        }
    }
    
    func getReading(for date: Date) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        let dateKey = formatter.string(from: date)
        
        if let entry = plan[dateKey] {
            return entry.family + entry.secret
        }
        
        return ["Genesis 1"] // Fallback
    }
}
