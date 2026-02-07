import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct JournalHomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    var addNewEntry: () -> Void
    var selectEntry: (JournalEntry) -> Void
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // Simplified State
    @State private var showLibrary = false
    @State private var showActivity = false
    @State private var selectedYear: Int?
    @State private var selectedMonth: Date?
    @State private var searchText: String = ""
    @State private var showSettings = false
    @State private var entryToRead: JournalEntry? = nil
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
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
            
            if showLibrary {
                libraryOverlay
            }
            
            if showActivity {
                activityOverlay
            }
            
            if let entry = entryToRead {
                entryReaderOverlay(entry)
            }
        }
        .background(settings.theme.backgroundColor)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear(perform: initializeSelection)
    }
    
    // MARK: - Overlays
    
    private var libraryOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showLibrary = false } }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { showLibrary = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                
                JournalColumnBrowser(
                    entries: entries,
                    selectedYear: $selectedYear,
                    selectedMonth: $selectedMonth,
                    onSelect: { entry in
                        withAnimation { showLibrary = false }
                        selectEntry(entry)
                    },
                    isCompact: false
                )
                .background(settings.theme.backgroundColor)
                .cornerRadius(20)
                .padding()
                .shadow(radius: 20)
            }
            .maxInternalWidth(900)
        }
    }
    
    private var activityOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showActivity = false } }
            
            VStack {
                Spacer()
                UnifiedHeatmapView()
                    .padding()
                    .background(settings.theme.backgroundColor)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                    .shadow(radius: 20)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    @ViewBuilder
    private func entryReaderOverlay(_ entry: JournalEntry) -> some View {
        ZStack {
            // Subtle dimming backround - separated for soft fade
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut) { entryToRead = nil } }
                .transition(.opacity) // Pure opacity for soft fade
            
            // The Card - with scale/opacity transition
            VStack(spacing: 0) {
                HStack {
                    Text(entry.date.formatted(date: .complete, time: .omitted))
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { withAnimation(.easeInOut) { entryToRead = nil } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundColor(.accentColor)
                        
                        if let sections = entry.sections, !sections.isEmpty {
                            ForEach(sections) { section in
                                Text(section.content)
                                    .font(.system(.body, design: .serif))
                                    .lineSpacing(6)
                            }
                        } else {
                            Text(entry.content)
                                .font(.system(.body, design: .serif))
                                .lineSpacing(6)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 600, maxHeight: 600)
            .background(settings.theme.backgroundColor)
            .cornerRadius(24)
            .shadow(radius: 30)
            .padding()
            .transition(.scale(scale: 0.9).combined(with: .opacity)) // Card scaling only
        }
        .zIndex(100) // Ensure it's on top
    }
    
    // MARK: - iOS Layout
    
    private var iosLayout: some View {
        ScrollView {
            VStack(spacing: 32) {
                iosHeader
                
                // Primary Action
                VStack(spacing: 16) {
                    Button(action: addNewEntry) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)
                            }
                            
                            Text("Journal Now")
                                .font(.system(.headline, design: .rounded).bold())
                                .foregroundColor(settings.theme.textColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
                
                // Search & Browse
                VStack(spacing: 24) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search your journal...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    
                    if !searchText.isEmpty {
                        SearchResultsList(entries: entries, searchText: searchText, onSelect: { entry in
                            withAnimation { entryToRead = entry }
                        })
                        .padding(.horizontal, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Entries")
                                    .font(.system(.headline, design: .serif))
                                Spacer()
                                Button(action: { withAnimation { showLibrary = true } }) {
                                    Text("View All")
                                        .font(.caption.bold())
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(entries.prefix(10)) { entry in
                                        Button(action: { withAnimation { entryToRead = entry } }) {
                                            JournalEntryCard(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                
                // Activity Toggle
                Button(action: { withAnimation { showActivity = true } }) {
                    Label("View Activity", systemImage: "chart.bar.fill")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var iosHeader: some View {
        HStack {
            Button(action: { sidebarSelection = .home }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(settings.theme.textColor.opacity(0.6))
                    .padding(10)
                    .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Text("Journal")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundColor(settings.theme.textColor)
            }
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Desktop Layout
    
    @ViewBuilder
    private var desktopLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Header Area (Fixed at top)
                HStack {
                    Button(action: { sidebarSelection = .home }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(settings.theme.textColor.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                    
                    Spacer()
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                }
                .zIndex(2)
                
                ScrollView {
                    VStack(spacing: 60) {
                        Spacer(minLength: 40)
                        
                        VStack(spacing: 40) {
                            Text("Journal")
                                .font(.system(size: 64, weight: .bold, design: .serif))
                                .foregroundColor(settings.theme.textColor)
                            
                            Button(action: addNewEntry) {
                                HStack(spacing: 12) {
                                    Image(systemName: "pencil.line")
                                    Text("Journal Now")
                                }
                                .font(.system(.title3, design: .rounded).bold())
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 15, x: 0, y: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    
                        VStack(spacing: 32) {
                            // Integrated Search
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search your thoughts...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 18, weight: .medium, design: .serif))
                            }
                            .padding(20)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(16)
                            .frame(maxWidth: 600)
                            
                            if !searchText.isEmpty {
                                SearchResultsList(entries: entries, searchText: searchText, onSelect: { entry in
                                    withAnimation { entryToRead = entry }
                                })
                                .frame(maxWidth: 800)
                            } else {
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack {
                                        Text("Recent Entries")
                                            .font(.system(.title3, design: .serif).bold())
                                        Spacer()
                                        Button("Archive") { withAnimation { showLibrary = true } }
                                            .font(.headline)
                                            .foregroundColor(.accentColor)
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 20) {
                                            ForEach(entries.prefix(10)) { entry in
                                                Button(action: { withAnimation { entryToRead = entry } }) {
                                                    JournalEntryCard(entry: entry)
                                                        .frame(width: 280)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.vertical, 10)
                                    }
                                }
                                .frame(maxWidth: 800)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        HStack(spacing: 40) {
                            Button(action: { withAnimation { showActivity = true } }) {
                                Label("Activity", systemImage: "chart.bar.fill")
                            }
                            .buttonStyle(.plain)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 60)
                        
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Results for \"\(searchText)\"")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if filteredEntries.isEmpty {
                Text("No entries found.")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredEntries) { entry in
                        Button(action: { onSelect(entry) }) {
                            JournalEntryListRow(entry: entry)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(settings.theme.textColor.opacity(0.03))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Journal Entry Card
struct JournalEntryCard: View {
    let entry: JournalEntry
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.system(.subheadline, design: .serif).bold())
                .foregroundColor(settings.theme.textColor)
            
            let content = entry.sections?.first?.content ?? entry.content
            Text(content.isEmpty ? "No content" : content)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(height: 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settings.theme.textColor.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
