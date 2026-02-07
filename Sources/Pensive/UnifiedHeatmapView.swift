import SwiftUI
import SwiftData

struct UnifiedHeatmapView: View {
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \ReadDay.dateString, order: .reverse) private var scriptureDays: [ReadDay]
    @Query(sort: \ReadArticle.dateRead, order: .reverse) private var studyArticles: [ReadArticle]
    @Query(sort: \PrayedDay.dateString, order: .reverse) private var prayerDays: [PrayedDay]
    
    @State private var displayYear: Int = Calendar.current.component(.year, from: Date())
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 20) {
            // Navigation Header
            HStack(spacing: 24) {
                Button(action: { withAnimation { displayYear -= 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 2) {
                    Text(String(displayYear))
                        .font(.system(.title3, design: .serif).bold())
                    Text("Activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                .frame(width: 120)
                
                Button(action: { withAnimation { displayYear += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(settings.theme.textColor)
            
            // Legend
            HStack(spacing: 16) {
                LegendItem(label: "Journal", color: .blue)
                LegendItem(label: "Scripture", color: .orange)
                LegendItem(label: "Study", color: .purple)
                LegendItem(label: "Prayer", color: .green)
            }
            .padding(.bottom, 8)
            
            // The Graph
            ScrollView(.horizontal, showsIndicators: false) {
                UnifiedYearGrid(
                    year: displayYear,
                    journalEntries: entries,
                    scriptureDays: scriptureDays,
                    studyArticles: studyArticles,
                    prayerDays: prayerDays
                )
                .containerRelativeFrame(.horizontal, alignment: .center)
                .padding(.horizontal)
            }
            .frame(height: 140)
        }
        .padding(.vertical, 24)
        .background(settings.theme.backgroundColor)
        .cornerRadius(24)
    }
}

struct LegendItem: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct UnifiedYearGrid: View {
    let year: Int
    let journalEntries: [JournalEntry]
    let scriptureDays: [ReadDay]
    let studyArticles: [ReadArticle]
    let prayerDays: [PrayedDay]
    
    private let calendar = Calendar.current
    
    var body: some View {
        let weeks = generateWeeks(for: year)
        
        VStack(alignment: .leading, spacing: 8) {
            // Month Labels
            HStack(spacing: 0) {
                ForEach(weeks.indices, id: \.self) { index in
                    if let monthName = getMonthName(for: weeks[index]) {
                        Text(monthName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 18, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Color.clear.frame(width: 18)
                    }
                }
            }
            
            // Days Grid
            HStack(spacing: 4) {
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    VStack(spacing: 4) {
                        ForEach(0..<7) { dayIndex in
                            if let date = weeks[weekIndex][dayIndex] {
                                DayCell(
                                    date: date,
                                    journal: hasJournal(on: date),
                                    scripture: hasScripture(on: date),
                                    study: hasStudy(on: date),
                                    prayer: hasPrayer(on: date)
                                )
                            } else {
                                Color.clear
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    .frame(width: 14)
                }
            }
        }
    }
    
    func hasJournal(on date: Date) -> Bool {
        journalEntries.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func hasScripture(on date: Date) -> Bool {
        let ds = formatDate(date)
        return scriptureDays.contains { $0.dateString == ds && $0.isRead }
    }
    
    func hasStudy(on date: Date) -> Bool {
        studyArticles.contains { calendar.isDate($0.dateRead, inSameDayAs: date) }
    }
    
    func hasPrayer(on date: Date) -> Bool {
        let ds = formatDate(date)
        return prayerDays.contains { $0.dateString == ds && $0.isPrayed }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func getMonthName(for week: [Date?]) -> String? {
        for day in week {
            if let d = day, calendar.component(.day, from: d) == 1 {
                return calendar.shortMonthSymbols[calendar.component(.month, from: d) - 1]
            }
        }
        return nil
    }
    
    func generateWeeks(for year: Int) -> [[Date?]] {
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: 7)
        let range = calendar.range(of: .day, in: .year, for: startOfYear)!
        
        for dayOffset in 0..<range.count {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            currentWeek[weekday - 1] = date
            if weekday == 7 {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
            }
        }
        if currentWeek.contains(where: { $0 != nil }) { weeks.append(currentWeek) }
        return weeks
    }
}

struct DayCell: View {
    let date: Date
    let journal: Bool
    let scripture: Bool
    let study: Bool
    let prayer: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.06))
                .frame(width: 14, height: 14)
            
            VStack(spacing: 1.5) {
                HStack(spacing: 1.5) {
                    activityDot(active: journal, color: .blue)
                    activityDot(active: scripture, color: .orange)
                }
                HStack(spacing: 1.5) {
                    activityDot(active: study, color: .purple)
                    activityDot(active: prayer, color: .green)
                }
            }
        }
        .help(date.formatted(date: .complete, time: .omitted))
    }
    
    @ViewBuilder
    func activityDot(active: Bool, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(active ? color : Color.clear)
            .frame(width: 5, height: 5)
    }
}
