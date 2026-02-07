import SwiftUI
import SwiftData
import MapKit
import WebKit

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
                TabView(selection: Binding(get: { sidebarSelection ?? .home }, set: { sidebarSelection = $0 })) {
                    HomeView(sidebarSelection: $sidebarSelection, selectedEntryID: $selectedEntryID)
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }
                        .tag(SidebarItem.home)
                    
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
                    
                    ScriptureView(sidebarSelection: $sidebarSelection)
                        .tabItem {
                            Label("Scripture", systemImage: "book")
                        }
                        .tag(SidebarItem.scripture)
                    
                    StudyView(sidebarSelection: $sidebarSelection)
                        .tabItem {
                            Label("Study", systemImage: "graduationcap")
                        }
                        .tag(SidebarItem.study)
                    
                    PrayHomeView(sidebarSelection: $sidebarSelection)
                        .tabItem {
                            Label("Pray", systemImage: "flame.fill")
                        }
                        .tag(SidebarItem.pray)
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
        
        // Find if an entry for today already exists
        if let todayEntry = entries.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            migrateLegacyContent(for: todayEntry)
            if selectedEntryID == nil {
                selectedEntryID = todayEntry.id
            }
        } else {
            // If no entry for today, create it silently
            let newEntry = JournalEntry(date: now)
            modelContext.insert(newEntry)
            
            // Add the first section
            let firstSection = JournalSection(content: "", timestamp: now)
            firstSection.entry = newEntry
            modelContext.insert(firstSection)
            
            selectedEntryID = newEntry.id
        }
    }
        
    private func addNewEntry() {
        // Reuse the auto-selection logic but force a new section if an entry already exists
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
            entry.content = "" // Clear after migration
        }
    }
}

struct JournalView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    let entries: [JournalEntry]
    @Binding var selectedEntryID: UUID?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let addNewEntry: () -> Void
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let entryID = selectedEntryID, let entry = entries.first(where: { $0.id == entryID }) {
                DetailView(
                    entry: entry, 
                    columnVisibility: $columnVisibility,
                    selectedEntryID: $selectedEntryID
                )
            } else {
                JournalHomeView(
                    sidebarSelection: $sidebarSelection,
                    addNewEntry: addNewEntry,
                    selectEntry: { entry in
                        selectedEntryID = entry.id
                    }
                )
                .environmentObject(settings)
            }
        }
        .navigationTitle("")
    }
}

enum StudyViewMode {
    case home
    case dashboard
}

struct StudyView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @State private var viewMode: StudyViewMode = .home
    @State private var selectedFeed: RSSFeed? = nil
    @State private var sortOrder: StudyHomeView.StudySortOrder = .recent

    var body: some View {
        Group {
            if viewMode == .home {
                StudyHomeView(
                    sidebarSelection: $sidebarSelection,
                    onSelectFeed: { feed, sort in
                        self.selectedFeed = feed
                        self.sortOrder = sort
                        withAnimation {
                            viewMode = .dashboard
                        }
                    }
                )
            } else {
                StudyDashboardView(
                    sidebarSelection: $sidebarSelection,
                    selectedFeed: selectedFeed,
                    sortOrder: sortOrder,
                    onBack: {
                        withAnimation {
                            viewMode = .home
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
    }
}

struct DetailView: View {
    @Bindable var entry: JournalEntry
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var selectedEntryID: UUID?
    @State private var isMenuExpanded = false
    
    // Picker state is now handled within SectionEditor
    
    var body: some View {
        ZStack(alignment: .bottom) {
            settings.theme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Centered, Dimmed Header
                HStack {
                    Spacer()
                    Text(entry.date.formatted(date: .long, time: .omitted))
                        .font(headerFont)
                        .foregroundColor(settings.theme.textColor)
                        .opacity(0.3)
                        .padding(.top, 60)
                        .padding(.bottom, 10)
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            let calculatedPadding = geometry.size.width * settings.marginPercentage
                            
                            if let firstSection = entry.sections?.first {
                                EntryEditor(
                                    section: firstSection,
                                    fontName: settings.font.name,
                                    fontSize: settings.textSize,
                                    textColor: settings.theme.textColor,
                                    selectionColor: settings.theme.selectionColor,
                                    horizontalPadding: calculatedPadding
                                )
                                .id(firstSection.id)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .onAppear {
            if (entry.sections ?? []).isEmpty {
                let firstSection = JournalSection(content: entry.content)
                firstSection.entry = entry
                modelContext.insert(firstSection)
                entry.content = ""
            }
        }
        .toolbar {
            #if os(macOS)
            let placement = ToolbarItemPlacement.navigation
            #else
            let placement = ToolbarItemPlacement.topBarTrailing
            #endif
            ToolbarItem(placement: placement) {
                ExpandingSettingsMenu(
                    entry: entry,
                    isExpanded: $isMenuExpanded,
                    columnVisibility: $columnVisibility,
                    selectedEntryID: $selectedEntryID
                ) {
                    selectedEntryID = nil
                }
            }
        }
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }
    
    private var headerFont: Font {
        switch settings.font {
        case .sans: return .system(.headline, design: .rounded)
        case .serif: return .system(.headline, design: .serif)
        case .mono: return .system(.headline, design: .monospaced)
        }
    }
}

struct EntryEditor: View {
    @Bindable var section: JournalSection
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    
    @State private var draftText: String = ""
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var isPickerPresented = false
    @State private var pickerQuery = ""
    @State private var pickerPosition: CGPoint = .zero
    @State private var selectedIndex = 0
    @State private var textHeight: CGFloat = 400
    
    var body: some View {
        NativeTextView(
            text: $draftText,
            height: $textHeight,
            fontName: fontName,
            fontSize: fontSize,
            textColor: textColor,
            selectionColor: selectionColor,
            horizontalPadding: horizontalPadding,
            isPickerPresented: $isPickerPresented,
            pickerQuery: $pickerQuery,
            pickerPosition: $pickerPosition,
            onCommand: handlePickerCommand
        )
        .frame(minHeight: textHeight)
        .overlay(alignment: .topLeading) {
            if isPickerPresented {
                SymbolPicker(query: $pickerQuery, selectedIndex: $selectedIndex) { item in
                    insertSymbol(item)
                }
                .padding(.top, 40)
                .padding(.leading, horizontalPadding + 20)
                .transition(.scale(0.9).combined(with: .opacity))
            }
        }
        .onAppear {
            draftText = section.content
        }
        .onDisappear {
            saveImmediately()
        }
        .onChange(of: draftText) { oldValue, newValue in
            // Debounce the save to the model
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
                if !Task.isCancelled {
                    await MainActor.run {
                        section.content = draftText
                    }
                }
            }
        }
    }
    
    private func saveImmediately() {
        saveTask?.cancel()
        section.content = draftText
    }
    
    private func handlePickerCommand(_ command: NativeTextView.ControlCommand) -> Bool {
        guard isPickerPresented else { return false }
        let filteredCount = filteredSymbolsCount()
        guard filteredCount > 0 else { return false }
        
        switch command {
        case .moveUp:
            selectedIndex = (selectedIndex - 1 + filteredCount) % filteredCount
            return true
        case .moveDown:
            selectedIndex = (selectedIndex + 1) % filteredCount
            return true
        case .confirm, .complete:
            if let item = getSelectedItem() {
                insertSymbol(item)
                return true
            }
        case .cancel:
            isPickerPresented = false
            return true
        }
        return false
    }
    
    private func filteredSymbolsCount() -> Int {
        if pickerQuery.isEmpty { return symbolMap.count }
        return symbolMap.filter { $0.name.lowercased().contains(pickerQuery.lowercased()) }.count
    }
    
    private func getSelectedItem() -> SymbolItem? {
        let filtered = pickerQuery.isEmpty ? symbolMap : symbolMap.filter { $0.name.lowercased().contains(pickerQuery.lowercased()) }
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }
    
    private func insertSymbol(_ item: SymbolItem) {
        let trigger = "/" + pickerQuery
        if let range = draftText.range(of: trigger, options: .backwards) {
            draftText.replaceSubrange(range, with: item.symbol)
            isPickerPresented = false
            pickerQuery = ""
        }
    }
}

struct ExpandingSettingsMenu: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Bindable var entry: JournalEntry
    @Binding var isExpanded: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var selectedEntryID: UUID?
    @State private var isTypographyPresented = false
    var onDeleted: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            toggleButton
            if isExpanded {
                expandedContent
            }
        }
    }

    private var toggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            Image(systemName: isExpanded ? "chevron.left" : "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .help(isExpanded ? "Collapse Settings" : "Expand Settings")
    }

    private var expandedContent: some View {
        HStack(spacing: 12) {
            Group {
                // Home Button (Back to Dashboard)
                Button(action: {
                    selectedEntryID = nil
                    // Need to potentially clear detail state if needed, but selectedEntryID = nil handles the navigation switch
                }) {
                    Image(systemName: "house")
                        .font(.system(size: 13))
                }
                .help("Back to Journal Home")
                
                Divider().frame(height: 12)

                // Text Size Controls
                HStack(spacing: 8) {
                    Button(action: { settings.textSize = max(12, settings.textSize - 1) }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 12))
                    }
                    .help("Smaller Text")
                    
                    Button(action: { settings.textSize = min(72, settings.textSize + 1) }) {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 12))
                    }
                    .help("Larger Text")
                }
                
                // Theme Quick Select
                HStack(spacing: 6) {
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: { settings.theme = theme }) {
                            Circle()
                                .fill(theme.backgroundColor)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(settings.theme.textColor.opacity(settings.theme == theme ? 0.8 : 0.2), lineWidth: 1)
                                )
                                .scaleEffect(settings.theme == theme ? 1.2 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .help(theme.rawValue.capitalized)
                    }
                }
            }
            .foregroundColor(settings.theme.textColor.opacity(0.7))

            typographyMenu
            dangerousActionsMenu
        }
        .padding(.leading, 8)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var typographyMenu: some View {
        Button(action: { isTypographyPresented.toggle() }) {
            Image(systemName: "textformat")
                .font(.system(size: 13))
                .foregroundColor(settings.theme.textColor.opacity(0.7))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isTypographyPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Font")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $settings.font) {
                    ForEach(AppFont.allCases) { font in
                        Text(font.rawValue.capitalized).tag(font)
                    }
                }
                #if os(macOS)
                .pickerStyle(.segmented)
                #else
                .pickerStyle(.menu)
                #endif
                .labelsHidden()
                
                Divider()
                
                Text("Column Width")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Button(action: { settings.marginPercentage = min(0.45, settings.marginPercentage + 0.05) }) {
                        Image(systemName: "minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Text("\(Int((1.0 - settings.marginPercentage * 2) * 100))%")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .frame(width: 40)
                    
                    Button(action: { settings.marginPercentage = max(0, settings.marginPercentage - 0.05) }) {
                        Image(systemName: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 200)
        }
        .help("Font & Margins")
    }

    private var dangerousActionsMenu: some View {
        Menu {
            Button(role: .destructive, action: { 
                modelContext.delete(entry)
                isExpanded = false
                onDeleted()
            }) {
                Label("Delete Entry", systemImage: "trash")
            }
            
            Button(action: {
                let locationManager = LocationManager()
                locationManager.requestLocation()
            }) {
                Label("Update Location", systemImage: "location")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13))
                .foregroundColor(settings.theme.textColor.opacity(0.7))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("More Actions")
    }
}

// FloatingToolbar removed and integrated into top-left menu

struct MiniMapView: View {
    let latitude: Double
    let longitude: Double
    
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))) {
            Marker("Journal Entry", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }
}

struct ToolbarIconButton: View {
    let icon: String
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

struct StudyDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var rssService: RSSService
    @EnvironmentObject var settings: AppSettings
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @Query private var allFeeds: [RSSFeed]
    
    var selectedFeed: RSSFeed?
    var sortOrder: StudyHomeView.StudySortOrder
    var onBack: () -> Void
    
    @State private var selectedJournal: RSSFeed? = nil
    @State private var searchText: String = ""
    @State private var showHistory = false
    @State private var isShuffling = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                StudyHeader(
                    sidebarSelection: $sidebarSelection,
                    selectedJournal: $selectedJournal,
                    searchText: $searchText,
                    showHistory: $showHistory,
                    isShuffling: $isShuffling,
                    onBack: onBack
                )
                
                StudyContent(searchText: searchText, selectedJournal: selectedJournal)
            }
            .blur(radius: isShuffling ? 10 : 0)
            .opacity(isShuffling ? 0.3 : 1.0)
            
            if isShuffling {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Text("Shuffling...")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isShuffling)
        .onAppear {
            selectedJournal = selectedFeed
            applyFeedSelection()
            
            // Initialization: if no feeds exist, add defaults
            if allFeeds.isEmpty {
                for feed in RSSFeed.defaults {
                    modelContext.insert(feed)
                }
            }
        }
        .onChange(of: selectedJournal) { _, newValue in
            applyFeedSelection()
        }
        .onChange(of: allFeeds) { _, _ in
            if selectedJournal == nil {
                applyFeedSelection()
            }
        }
        .onChange(of: rssService.items.count) { _, _ in
            rssService.sortItems(by: sortOrder)
        }
        .sheet(isPresented: $showHistory) {
            ReadHistoryView()
        }
        .background(settings.theme.backgroundColor)
    }
    
    private func applyFeedSelection() {
        if let journal = selectedJournal {
            rssService.fetchFeed(url: journal.rssURL!, journalName: journal.name)
        } else {
            rssService.fetchAllFeeds(feeds: Array(allFeeds))
        }
        
        // Apply sort order
        rssService.sortItems(by: sortOrder)
    }
}

struct StudyHeader: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var feeds: [RSSFeed]
    @EnvironmentObject var rssService: RSSService
    @EnvironmentObject var settings: AppSettings
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @Binding var selectedJournal: RSSFeed?
    @Binding var searchText: String
    @Binding var showHistory: Bool
    @Binding var isShuffling: Bool
    var onBack: () -> Void
    @State private var showFeedManager = false
    @State private var shuffleRotation: Double = 0
    @Query private var readArticles: [ReadArticle]
    
    var dailyReadCount: Int {
        let calendar = Calendar.current
        return readArticles.filter { calendar.isDateInToday($0.dateRead) }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main Toolbar
            HStack(spacing: 20) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Study")
                        .font(.system(.title2, design: .rounded).bold())
                    
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 10))
                        Text("\(dailyReadCount) articles today")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField("Search your feeds...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)
                .frame(maxWidth: 300)
                
                // Controls Group
                HStack(spacing: 16) {
                    // Filter
                    Picker("Filter", selection: $settings.studyFilter) {
                        Text("All").tag(StudyFilter.all)
                        Text("Unread").tag(StudyFilter.unread)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .controlSize(.small)
                    
                    // Layout & Density
                    HStack(spacing: 0) {
                        Button(action: { settings.studyLayoutStyle = .grid }) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(8)
                        .background(settings.studyLayoutStyle == .grid ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundColor(settings.studyLayoutStyle == .grid ? .accentColor : .secondary)
                        
                        Divider().frame(height: 16)
                        
                        Button(action: { settings.studyLayoutStyle = .list }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(8)
                        .background(settings.studyLayoutStyle == .list ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundColor(settings.studyLayoutStyle == .list ? .accentColor : .secondary)
                    }
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    
                    if settings.studyLayoutStyle == .grid {
                        HStack(spacing: 4) {
                            Button(action: { if settings.studyColumns > 1 { settings.studyColumns -= 1 } }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text("\(settings.studyColumns)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 20)
                            Button(action: { if settings.studyColumns < 6 { settings.studyColumns += 1 } }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                        .foregroundColor(.secondary)
                    }
                }
                
                // Actions
                HStack(spacing: 8) {
                    Button(action: {
                        // 1. Start the dimming animation immediately
                        withAnimation(.easeIn(duration: 0.3)) {
                            isShuffling = true
                        }
                        
                        // 2. Perform the data shuffle after the screen is sufficiently dimmed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            // Non-animated shuffle to avoid jumping behind the blur
                            rssService.shuffleItemsImmediate()
                            
                            // 3. Wait a moment at maximum dimness for a satisfying feel
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    isShuffling = false
                                }
                            }
                        }
                    }) {
                        Image(systemName: "shuffle")
                            .rotationEffect(.degrees(shuffleRotation))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showFeedManager = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Source Picker
            HStack {
                Text("Source:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Picker("Journal", selection: $selectedJournal) {
                    Text("All Sources").tag(Optional<RSSFeed>.none)
                    Divider()
                    ForEach(feeds) { feed in
                        Text(feed.name).tag(Optional(feed))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 200)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(settings.theme.backgroundColor)
        .overlay(Divider(), alignment: .bottom)
        .sheet(isPresented: $showFeedManager) {
            FeedManagementView()
        }
    }
}

struct StudyContent: View {
    @EnvironmentObject var rssService: RSSService
    @EnvironmentObject var settings: AppSettings
    @Query private var readArticles: [ReadArticle]
    let searchText: String
    let selectedJournal: RSSFeed?
    
    var filteredItems: [RSSItem] {
        var items = rssService.items
        
        // Unread filter
        if settings.studyFilter == .unread {
            let readUrls = Set(readArticles.map { $0.url })
            items = items.filter { !readUrls.contains($0.link) }
        }
        
        // Search filter
        if !searchText.isEmpty {
            items = items.filter { 
                $0.cleanTitle.localizedCaseInsensitiveContains(searchText) || 
                $0.cleanDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    var body: some View {
        if rssService.isFetching {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Text("Updating your library...")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if settings.studyLayoutStyle == .grid {
                    MasonryVStack(columns: settings.studyColumns, data: filteredItems) { item in
                        StudyArticleCard(item: item, journalName: item.journalName, category: "Article")
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            StudyArticleRow(item: item)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .animation(.default, value: filteredItems)
        }
    }
}

struct StudyArticleRow: View {
    @Environment(\.modelContext) private var modelContext
    let item: RSSItem
    @Query private var readArticles: [ReadArticle]
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openURL) private var openURL
    
    var isRead: Bool {
        readArticles.contains { $0.url == item.link }
    }
    
    var body: some View {
        Button(action: {
            if let url = URL(string: item.link) {
                openURL(url)
                if !isRead {
                    let newRead = ReadArticle(url: item.link, title: item.cleanTitle, category: "Article", publicationName: item.journalName)
                    modelContext.insert(newRead)
                }
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.cleanTitle)
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(settings.theme.textColor.opacity(isRead ? 0.5 : 1.0))
                        .lineLimit(2)
                    
                    HStack {
                        Text(item.journalName)
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                        Text("•")
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green.opacity(0.3))
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(settings.theme.backgroundColor)
            .overlay(Divider(), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}



struct ReadHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadArticle.dateRead, order: .reverse) private var readArticles: [ReadArticle]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @State private var filterFlaggedOnly = false
    
    var filteredArticles: [ReadArticle] {
        if filterFlaggedOnly {
            return readArticles.filter { $0.isFlagged }
        } else {
            return readArticles
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Study History")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Starred Only", isOn: $filterFlaggedOnly)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            if filteredArticles.isEmpty {
                ContentUnavailableView(
                    filterFlaggedOnly ? "No starred articles" : "No articles read yet",
                    systemImage: filterFlaggedOnly ? "star.slash" : "book.closed"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredArticles) { article in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.system(.headline, design: .serif))
                                    .foregroundColor(settings.theme.textColor)
                                
                                HStack {
                                    Text(article.publicationName)
                                        .font(.caption.bold())
                                        .foregroundColor(.accentColor)
                                    Text("•")
                                    Text(article.dateRead.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { article.isFlagged.toggle() }) {
                                Image(systemName: article.isFlagged ? "star.fill" : "star")
                                    .foregroundColor(article.isFlagged ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(settings.theme.backgroundColor)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(filteredArticles[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}


extension View {
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}
