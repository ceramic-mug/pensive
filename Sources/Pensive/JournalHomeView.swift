import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct JournalHomeView: View {
    var addNewEntry: () -> Void
    var selectEntry: (JournalEntry) -> Void
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // Browser State
    @State private var selectedYear: Int?
    @State private var selectedMonth: Date?
    
    // Search State
    @State private var searchText: String = ""
    @State private var showSettings = false
    
    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .compact {
                iosLayout
            } else {
                desktopLayout
            }
            #else
            desktopLayout
            #endif
        }
        .background(settings.theme.backgroundColor)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear(perform: initializeSelection)
    }
    
    // MARK: - iOS Layout
    
    private var iosLayout: some View {
        VStack(spacing: 0) {
            iosHeader
            
            // Action Card
            iosActionCard
            
            // Search Bar
            iosSearchBar
            
            // Recent Entries
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Entries")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    if entries.isEmpty {
                        noEntriesView
                    } else if !searchText.isEmpty {
                        SearchResultsList(entries: entries, searchText: searchText, onSelect: selectEntry)
                    } else {
                        recentEntriesList
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .background(settings.theme.backgroundColor.ignoresSafeArea())
    }
    
    private var iosHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Journal")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundColor(settings.theme.textColor)
                
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 20)
        .background(settings.theme.backgroundColor)
    }
    
    private var iosActionCard: some View {
        Button(action: addNewEntry) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "pencil.line")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Entry")
                        .font(.headline)
                        .foregroundColor(settings.theme.textColor)
                    Text("Write down your thoughts...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(settings.theme.textColor.opacity(0.05))
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
    
    private var iosSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search entries...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(settings.theme.textColor.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var noEntriesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No entries yet")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var recentEntriesList: some View {
        ForEach(entries.prefix(10)) { entry in
            Button(action: { selectEntry(entry) }) {
                JournalEntryListRow(entry: entry)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Desktop Layout
    
    private var desktopLayout: some View {
        VStack(spacing: 0) {
            // Header Area
            ZStack(alignment: .top) {
                // Top Right Search
                HStack {
                    Spacer()
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.custom(settings.font.name, size: 13))
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .frame(width: 200)
                    .padding(.trailing, 20)
                    .padding(.top, 32)
                }
                
                // Centered Title & Action
                VStack(spacing: 16) {
                    Text("Journal")
                        .font(.system(size: 56, weight: .bold, design: .serif))
                        .foregroundColor(settings.theme.textColor)
                        .padding(.top, 100)
                    
                    Button(action: addNewEntry) {
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.line")
                            Text("Journal Now")
                        }
                        .font(.system(.title3, design: .rounded).bold())
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                Color.accentColor
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
            .background(settings.theme.backgroundColor)
            
            // Main Content Area
            Group {
                if !searchText.isEmpty {
                    SearchResultsList(
                        entries: entries,
                        searchText: searchText,
                        onSelect: selectEntry
                    )
                } else {
                    JournalColumnBrowser(
                        entries: entries,
                        selectedYear: $selectedYear,
                        selectedMonth: $selectedMonth,
                        onSelect: selectEntry,
                        isCompact: false
                    )
                }
            }
            .frame(height: 420)
            .frame(maxWidth: 900)
            .padding(.top, 20)
            
            Spacer()
            
            // Compact Heatmap
            CompactHeatmapView(entries: entries)
                .padding(16)
                .background(settings.theme.backgroundColor)
        }
    }
    
    private func initializeSelection() {
        if selectedYear == nil {
            let currentYear = Calendar.current.component(.year, from: Date())
            if entries.contains(where: { Calendar.current.component(.year, from: $0.date) == currentYear }) {
                selectedYear = currentYear
            } else {
                selectedYear = Calendar.current.component(.year, from: entries.first?.date ?? Date())
            }
        }
    }
}

// MARK: - Column Browser
enum BrowserCategory: Hashable, Identifiable {
    case favorites
    case year(Int)
    
    var id: String {
        switch self {
        case .favorites: return "favorites"
        case .year(let y): return String(y)
        }
    }
}

struct JournalColumnBrowser: View {
    let entries: [JournalEntry]
    @Binding var selectedYear: Int?
    @Binding var selectedMonth: Date?
    let onSelect: (JournalEntry) -> Void
    let isCompact: Bool
    @EnvironmentObject var settings: AppSettings
    
    @State private var selectedCategory: BrowserCategory?
    @State private var selectedEntryID: JournalEntry.ID? // Selection state
    
    private let calendar = Calendar.current
    
    var categories: [BrowserCategory] {
        var cats: [BrowserCategory] = [.favorites]
        let uniqueYears = Set(entries.map { calendar.component(.year, from: $0.date) })
        let sortedYears = Array(uniqueYears).sorted(by: >)
        cats.append(contentsOf: sortedYears.map { .year($0) })
        return cats
    }
    
    var monthsInSelectedCategory: [Date] {
        guard let category = selectedCategory else { return [] }
        switch category {
        case .favorites:
            return []
        case .year(let year):
            let yearEntries = entries.filter { calendar.component(.year, from: $0.date) == year }
            let uniqueMonths = Set(yearEntries.map { entry in
                calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date))!
            })
            return Array(uniqueMonths).sorted(by: >)
        }
    }
    
    var displayedEntries: [JournalEntry] {
        guard let category = selectedCategory else { return [] }
        
        switch category {
        case .favorites:
            return entries.filter { $0.isFavorite }.sorted(by: { $0.date > $1.date })
            
        case .year(let year):
            if let month = selectedMonth {
                return entries.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                    .sorted(by: { $0.date > $1.date })
            } else {
                return entries.filter { calendar.component(.year, from: $0.date) == year }
                    .sorted(by: { $0.date > $1.date })
            }
        }
    }
    
    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                // Column 1: Categories
                VStack(spacing: 0) {
                    ListHeader(title: "Time")
                    List(categories, id: \.self, selection: $selectedCategory) { category in
                        CategoryRow(category: category)
                    }
                    .listStyle(.plain)
                }
                .frame(width: isCompact ? 100 : 120)
                
                Divider()
                
                // Column 2: Months
                if !isCompact || selectedCategory != nil {
                    MonthColumn(selectedCategory: selectedCategory, selectedMonth: $selectedMonth, months: monthsInSelectedCategory)
                        .frame(width: isCompact ? 110 : 140)
                    
                    Divider()
                }
                
                // Column 3: Entries
                EntryColumn(entries: displayedEntries, selectedEntryID: $selectedEntryID, onSelect: onSelect)
            }
            .border(Color.primary.opacity(0.1), width: 1)
        }
        .onAppear {
            if selectedCategory == nil {
                if let y = selectedYear {
                   selectedCategory = .year(y)
                } else if let maxYear = Set(entries.map { calendar.component(.year, from: $0.date) }).max() {
                    selectedCategory = .year(maxYear)
                } else {
                    selectedCategory = .favorites
                }
            }
        }
        .onChange(of: selectedCategory) { _, newValue in
            if case .year(let y) = newValue {
                selectedYear = y
            }
        }
    }
}

// Sub-views to break up body complexity
struct CategoryRow: View {
    let category: BrowserCategory
    var body: some View {
        HStack {
            switch category {
            case .favorites:
                Label {
                    Text("Favorites").foregroundColor(.primary)
                } icon: {
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                }
            case .year(let y):
                Text(String(y))
                    .font(.system(.body, design: .monospaced))
            }
            Spacer()
        }
        .tag(category)
    }
}

struct MonthColumn: View {
    let selectedCategory: BrowserCategory?
    @Binding var selectedMonth: Date?
    let months: [Date]
    
    var body: some View {
        VStack(spacing: 0) {
            ListHeader(title: "Month")
            if case .favorites = selectedCategory {
                Spacer()
                Text("All Favorites")
                    .foregroundColor(.secondary)
                    .italic()
                Spacer()
            } else {
                List(selection: $selectedMonth) {
                    Text("All Months").tag(Optional<Date>.none)
                    ForEach(months, id: \.self) { month in
                        Text(month.formatted(.dateTime.month(.wide)))
                            .font(.system(.body, design: .rounded))
                            .padding(.vertical, 4)
                            .tag(Optional(month))
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct EntryColumn: View {
    let entries: [JournalEntry]
    @Binding var selectedEntryID: JournalEntry.ID?
    let onSelect: (JournalEntry) -> Void
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 0) {
            ListHeader(title: "Entries")
            List(entries, selection: $selectedEntryID) { entry in
                JournalEntryListRow(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onSelect(entry) }
                    .tag(entry.id)
                    .listRowSeparator(.visible)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteEntry(entry) } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button { toggleFavorite(entry) } label: { Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: entry.isFavorite ? "star.slash" : "star.fill") }.tint(.yellow)
                        Button { copyEntry(entry) } label: { Label("Copy", systemImage: "doc.on.doc") }.tint(.gray)
                    }
                    .contextMenu {
                        Button("Open") { onSelect(entry) }
                        Button(action: { toggleFavorite(entry) }) { Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: entry.isFavorite ? "star.slash" : "star.fill") }
                        Button(action: { copyEntry(entry) }) { Label("Copy Text", systemImage: "doc.on.doc") }
                        Button(role: .destructive, action: { deleteEntry(entry) }) { Label("Delete", systemImage: "trash") }
                    }
            }
            .listStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func toggleFavorite(_ entry: JournalEntry) {
        entry.isFavorite.toggle()
        try? modelContext.save()
    }
    
    private func deleteEntry(_ entry: JournalEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
    
    private func copyEntry(_ entry: JournalEntry) {
        let dateHeader = entry.date.formatted(date: .long, time: .shortened)
        let bodyText = (entry.sections?.isEmpty == false) ? entry.sections!.compactMap(\.content).joined(separator: "\n\n") : entry.content
        let fullText = "\(dateHeader)\n\n\(bodyText)"
        
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        #else
        UIPasteboard.general.string = fullText
        #endif
    }
}

struct ListHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.1)),
            alignment: .bottom
        )
    }
}

struct JournalEntryListRow: View {
    let entry: JournalEntry
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.date.formatted(date: .complete, time: .shortened))
                .font(.system(.headline, design: .serif))
                .foregroundColor(settings.theme.textColor)
            
            let content = entry.sections?.first?.content ?? entry.content
            Text(content.isEmpty ? "No content" : content.replacingOccurrences(of: "\n", with: " "))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search Results
struct SearchResultsList: View {
    let entries: [JournalEntry]
    let searchText: String
    let onSelect: (JournalEntry) -> Void
    @EnvironmentObject var settings: AppSettings
    
    var filteredEntries: [JournalEntry] {
        entries.filter { entry in
            let contentMatch = entry.content.localizedCaseInsensitiveContains(searchText)
            let sectionMatch = (entry.sections ?? []).contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            return contentMatch || sectionMatch
        }
        .sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Search Results for \"\(searchText)\"")
                .font(.headline)
                .padding()
                .foregroundColor(.secondary)
            
            List {
                ForEach(filteredEntries) { entry in
                    Button(action: { onSelect(entry) }) {
                        JournalEntryListRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Compact & Year Heatmap
// MARK: - Year Heatmap
struct CompactHeatmapView: View {
    let entries: [JournalEntry]
    @EnvironmentObject var settings: AppSettings
    @State private var displayYear: Int = Calendar.current.component(.year, from: Date())
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 12) {
            // Navigation Header
            HStack(spacing: 16) {
                Button(action: { withAnimation { displayYear -= 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                
                Text(String(displayYear))
                    .font(.system(.subheadline, design: .serif).bold())
                    .frame(width: 60)
                
                Button(action: { withAnimation { displayYear += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.secondary)
            
            // The Graph
            ScrollView(.horizontal, showsIndicators: false) {
                YearHeatmapGrid(entries: entries, year: displayYear)
                    .padding(.horizontal)
            }
            .frame(height: 110)
        }
        .padding(.vertical, 8)
    }
}

struct YearHeatmapGrid: View {
    let entries: [JournalEntry]
    let year: Int
    private let calendar = Calendar.current
    
    var body: some View {
        let weeks = generateWeeks(for: year)
        
        VStack(alignment: .leading, spacing: 6) {
            // Month Labels
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(weeks.indices, id: \.self) { index in
                    let week = weeks[index]
                    if let monthName = getMonthName(for: week) {
                        Text(monthName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .fixedSize() // Allow overflow
                            .frame(width: 11, alignment: .leading) // Lock to grid column width
                    } else {
                        Color.clear
                            .frame(width: 11, height: 10)
                    }
                }
            }
            
            // Days Grid
            HStack(spacing: 2) {
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    VStack(spacing: 2) {
                        ForEach(0..<7) { dayIndex in
                            if let date = weeks[weekIndex][dayIndex] {
                                let hasEntry = hasEntry(on: date)
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(hasEntry ? Color.accentColor : Color.primary.opacity(0.06))
                                    .frame(width: 11, height: 11)
                                    .help(date.formatted(date: .complete, time: .omitted))
                            } else {
                                Color.clear
                                    .frame(width: 11, height: 11)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // Helper to get month name if this week starts a new month
    func getMonthName(for week: [Date?]) -> String? {
        for day in week {
            if let d = day {
                let dayNum = calendar.component(.day, from: d)
                if dayNum <= 7 { // Simple heuristic: Is this the first week of the month?
                                 // Actually better: Check if this week contains day 1.
                    if dayNum == 1 {
                        let m = calendar.component(.month, from: d)
                        return calendar.shortMonthSymbols[m - 1]
                    }
                }
            }
        }
        return nil
    }
    
    // Data Generation
    func generateWeeks(for year: Int) -> [[Date?]] {
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: 7)
        
        // Find weekday of Jan 1
        _ = calendar.component(.weekday, from: startOfYear) // 1=Sun
        
        // Offset logic: if grid starts loops at 0 (Sun), exact match.
        // We need to pad the first week if it doesn't start on Sunday
        // Logic: week array is [Sun, Mon, Tue...]
        // If Jan 1 is Wed (4), then indices 0,1,2 are nil. 3 is Jan 1.
        
        // Loop through all days of year
        let range = calendar.range(of: .day, in: .year, for: startOfYear)!
        
        for dayOffset in 0..<range.count {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear) else { continue }
            let weekday = calendar.component(.weekday, from: date) // 1...7
            
            let arrayIndex = weekday - 1 // 0...6
            currentWeek[arrayIndex] = date
            
            if weekday == 7 { // Saturday, end of week
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
            }
        }
        // Append partial last week
        if currentWeek.contains(where: { $0 != nil }) {
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    func hasEntry(on date: Date) -> Bool {
        entries.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
