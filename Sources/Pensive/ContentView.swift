import SwiftUI
import SwiftData
import MapKit
import WebKit

// MARK: - Notifications
extension Notification.Name {
    static let resetTab = Notification.Name("resetTab")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    
    @State private var selectedEntryID: UUID?
    @State private var searchText: String = ""
    #if os(macOS)
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly
    #else
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    #endif
    @State private var sidebarSelection: SidebarItem? = .home
    @Environment(\.horizontalSizeClass) var sizeClass
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case journal = "Journal"
        case scripture = "Scripture"
        case study = "Study"
        case pray = "Pray"
        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .home: return "house"
            case .journal: return "pencil.line"
            case .scripture: return "book"
            case .study: return "graduationcap"
            case .pray: return "flame.fill"
            }
        }
    }
    
    var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        } else {
            return entries.filter { entry in
                let contentMatch = entry.content.localizedCaseInsensitiveContains(searchText)
                let sectionMatch = (entry.sections ?? []).contains { $0.content.localizedCaseInsensitiveContains(searchText) }
                return contentMatch || sectionMatch
            }
        }
    }
    
    @State private var showSettings = false
    
    var body: some View {
        Group {
            if sizeClass == .compact {
                TabView(selection: Binding(
                    get: { sidebarSelection ?? .home },
                    set: { newValue in
                        if sidebarSelection == newValue {
                            // User tapped the already selected tab
                            if newValue == .journal {
                                selectedEntryID = nil
                            }
                            NotificationCenter.default.post(name: .resetTab, object: newValue)
                        }
                        sidebarSelection = newValue
                    }
                )) {
                    HomeView(sidebarSelection: $sidebarSelection, selectedEntryID: $selectedEntryID)
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }
                        .tag(SidebarItem.home)
                    
                    ScriptureView(sidebarSelection: $sidebarSelection)
                        .tabItem {
                            Label("Scripture", systemImage: "book")
                        }
                        .tag(SidebarItem.scripture)
                    
                    PrayHomeView(sidebarSelection: $sidebarSelection)
                        .tabItem {
                            Label("Prayer", systemImage: "flame.fill")
                        }
                        .tag(SidebarItem.pray)
                    
                    JournalView(
                        sidebarSelection: $sidebarSelection,
                        entries: filteredEntries,
                        selectedEntryID: $selectedEntryID,
                        columnVisibility: $columnVisibility,
                        addNewEntry: addNewEntry
                    )
                    .tabItem {
                        Label("Journal", systemImage: "pencil.line")
                    }
                    .tag(SidebarItem.journal)
                    
                    StudyView(sidebarSelection: $sidebarSelection)
                        .tabItem {
                            Label("Study", systemImage: "graduationcap")
                        }
                        .tag(SidebarItem.study)
                }
                .accentColor(.accentColor)
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    List(selection: $sidebarSelection) {
                        Section {
                            ForEach(SidebarItem.allCases) { item in
                                NavigationLink(value: item) {
                                    Label(item.rawValue, systemImage: item.icon)
                                }
                                .foregroundColor(sidebarSelection == item ? .accentColor : .primary)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("Pensive")
                } detail: {
                    if sidebarSelection == .home {
                        HomeView(
                            sidebarSelection: Binding(
                                get: { sidebarSelection ?? .home },
                                set: { sidebarSelection = $0 }
                            ),
                            selectedEntryID: $selectedEntryID
                        )
                    } else if sidebarSelection == .journal {
                        JournalView(
                            sidebarSelection: $sidebarSelection,
                            entries: filteredEntries,
                            selectedEntryID: $selectedEntryID,
                            columnVisibility: $columnVisibility,
                            addNewEntry: addNewEntry
                        )
                    } else if sidebarSelection == .scripture {
                        ScriptureView(sidebarSelection: $sidebarSelection)
                    } else if sidebarSelection == .study {
                        StudyView(sidebarSelection: $sidebarSelection)
                    } else {
                        PrayHomeView(sidebarSelection: $sidebarSelection)
                    }
                }
                .modify {
                    #if os(macOS)
                    if #available(macOS 15.0, *) {
                        $0.windowToolbarFullScreenVisibility(.onHover)
                    } else {
                        $0
                    }
                    #else
                    $0
                    #endif
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettings"))) { _ in
            showSettings = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .background(
            Group {
                #if os(macOS)
                Button("") { settings.textSize = min(72, settings.textSize + 2) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("") { settings.textSize = max(12, settings.textSize - 2) }
                    .keyboardShortcut("-", modifiers: .command)
                #endif
            }
            .opacity(0)
        )
        .preferredColorScheme(settings.theme == .dark ? .dark : .light)
    }
        
    private func autoSelectTodayEntry() {
        let now = Date()
        let calendar = Calendar.current
        
        if let todayEntry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            migrateLegacyContent(for: todayEntry)
            if selectedEntryID == nil {
                selectedEntryID = todayEntry.id
            }
        } else {
            let newEntry = JournalEntry(date: now)
            modelContext.insert(newEntry)
            let firstSection = JournalSection(content: "", timestamp: now)
            firstSection.entry = newEntry
            modelContext.insert(firstSection)
            selectedEntryID = newEntry.id
        }
    }
        
    private func addNewEntry() {
        let now = Date()
        let calendar = Calendar.current
        
        if let existingEntry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            migrateLegacyContent(for: existingEntry)
            let newSection = JournalSection(content: "", timestamp: now)
            newSection.entry = existingEntry
            modelContext.insert(newSection)
            selectedEntryID = existingEntry.id
        } else {
            autoSelectTodayEntry()
        }
    }
    
    private func migrateLegacyContent(for entry: JournalEntry) {
        if !entry.content.isEmpty && (entry.sections ?? []).isEmpty {
            let migratedSection = JournalSection(content: entry.content, timestamp: entry.date)
            entry.sections?.append(migratedSection)
            entry.content = ""
        }
    }
}

extension View {
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}
