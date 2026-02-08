import SwiftUI
import SwiftData

struct IOSJournalBrowserView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var allEntries: [JournalEntry]
    
    @State private var searchText: String = ""
    @State private var selectedYear: Int?
    @State private var selectedMonth: Int? // 1-12
    @State private var onlyFavorites: Bool = false
    @State private var entryToRead: JournalEntry? = nil
    
    private let calendar = Calendar.current
    
    var filteredEntries: [JournalEntry] {
        allEntries.filter { entry in
            let matchesSearch = searchText.isEmpty || 
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                (entry.sections ?? []).contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            
            let matchesYear = selectedYear == nil || calendar.component(.year, from: entry.date) == selectedYear
            let matchesMonth = selectedMonth == nil || calendar.component(.month, from: entry.date) == selectedMonth
            let matchesFavorites = !onlyFavorites || entry.isFavorite
            
            return matchesSearch && matchesYear && matchesMonth && matchesFavorites
        }
    }
    
    var availableYears: [Int] {
        let years = Set(allEntries.map { calendar.component(.year, from: $0.date) })
        return Array(years).sorted(by: >)
    }
    
    var availableMonths: [Int] {
        if let year = selectedYear {
            let months = Set(allEntries.filter { calendar.component(.year, from: $0.date) == year }
                .map { calendar.component(.month, from: $0.date) })
            return Array(months).sorted()
        }
        return Array(1...12)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Filter Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterButton(title: "All", isActive: selectedYear == nil && selectedMonth == nil && !onlyFavorites) {
                                selectedYear = nil
                                selectedMonth = nil
                                onlyFavorites = false
                            }
                            
                            FilterButton(title: "Favorites", isActive: onlyFavorites, icon: "star.fill") {
                                onlyFavorites.toggle()
                            }
                            
                            Menu {
                                Button("All Years") { selectedYear = nil; selectedMonth = nil }
                                ForEach(availableYears, id: \.self) { year in
                                    Button(String(year)) { selectedYear = year; selectedMonth = nil }
                                }
                            } label: {
                                FilterButton(title: selectedYear.map(String.init) ?? "Year", isActive: selectedYear != nil, isMenu: true)
                            }
                            
                            if selectedYear != nil {
                                Menu {
                                    Button("All Months") { selectedMonth = nil }
                                    ForEach(availableMonths, id: \.self) { month in
                                        Button(calendar.monthSymbols[month-1]) { selectedMonth = month }
                                    }
                                } label: {
                                    FilterButton(title: selectedMonth.map { calendar.monthSymbols[$0-1] } ?? "Month", isActive: selectedMonth != nil, isMenu: true)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(settings.theme.backgroundColor)
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if filteredEntries.isEmpty {
                                ContentUnavailableView(
                                    "No Entries Found",
                                    systemImage: "pencil.and.outline",
                                    description: Text("Try adjusting your filters or search.")
                                )
                                .padding(.top, 100)
                            } else {
                                ForEach(filteredEntries) { entry in
                                    EntryCard(entry: entry) {
                                        withAnimation(.easeInOut) {
                                            entryToRead = entry
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .navigationTitle("Archive")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .searchable(text: $searchText, prompt: "Search archive")
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                    #else
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                    #endif
                }
                .background(settings.theme.backgroundColor)
                
                if let entry = entryToRead {
                    JournalEntryReader(entry: entry, onClose: {
                        withAnimation(.easeInOut) { entryToRead = nil }
                    })
                    .environmentObject(settings)
                }
            }
        }
    }
}

struct FilterButton: View {
    let title: String
    let isActive: Bool
    var icon: String? = nil
    var isMenu: Bool = false
    var action: (() -> Void)? = nil
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(settings.font.swiftUIFont(size: 14, weight: isActive ? Font.Weight.bold : Font.Weight.medium))
                
                if isMenu {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .opacity(0.5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor : Color.primary.opacity(0.05))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct EntryCard: View {
    let entry: JournalEntry
    var action: () -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(entry.date.formatted(date: .complete, time: .omitted))
                        .font(settings.font.swiftUIFont(size: 14, weight: Font.Weight.semibold))
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                    
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(settings.font.swiftUIFont(size: 12))
                        .foregroundColor(.secondary)
                }
                
                let content = entry.sections?.first?.content ?? entry.content
                Text(content.isEmpty ? "No content" : content)
                    .font(settings.font.swiftUIFont(size: 16))
                    .foregroundColor(settings.theme.textColor)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(settings.theme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.primary.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { modelContext.delete(entry) } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            Button { entry.isFavorite.toggle() } label: { Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: entry.isFavorite ? "star.slash" : "star.fill") }.tint(.yellow)
        }
    }
}
