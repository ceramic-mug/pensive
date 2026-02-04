#if os(macOS)
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
    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly
    @State private var sidebarSelection: SidebarItem = .home
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case journal = "Journal"
        case scripture = "Scripture"
        case study = "Study"
        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .home: return "house"
            case .journal: return "pencil.line"
            case .scripture: return "book"
            case .study: return "graduationcap"
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
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(SidebarItem.allCases) { item in
                            Button(action: { sidebarSelection = item }) {
                                Label(item.rawValue, systemImage: item.icon)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(sidebarSelection == item ? .accentColor : .primary)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("")
        } detail: {
            if sidebarSelection == .home {
                HomeView(
                    sidebarSelection: $sidebarSelection,
                    selectedEntryID: $selectedEntryID
                )
            } else if sidebarSelection == .journal {
                JournalView(
                    entries: entries,
                    selectedEntryID: $selectedEntryID,
                    columnVisibility: $columnVisibility,
                    addNewEntry: addNewEntry
                )
            } else if sidebarSelection == .scripture {
                ScriptureView()
            } else {
                StudyView()
            }
        }
        .modify {
            if #available(macOS 15.0, *) {
                $0.windowToolbarFullScreenVisibility(.onHover)
            } else {
                $0
            }
        }
        .background(
                Group {
                    Button("") { settings.textSize = min(72, settings.textSize + 2) }
                        .keyboardShortcut("+", modifiers: .command)
                    Button("") { settings.textSize = max(12, settings.textSize - 2) }
                        .keyboardShortcut("-", modifiers: .command)
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

struct StudyView: View {
    var body: some View {
        MedicalJournalBrowserView()
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
            ToolbarItem(placement: .navigation) {
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
        .toolbarBackground(.hidden, for: .windowToolbar)
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
                .pickerStyle(.segmented)
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

struct MedicalJournalBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var rssService: RSSService
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \ReadArticle.dateRead, order: .reverse) private var readArticles: [ReadArticle]
    @State private var selectedJournal: MedicalJournal? = MedicalJournal.defaults[0]
    @State private var searchText: String = "" // Added for article search
    @State private var showHistory = false
    
    var dailyReadCount: Int {
        let calendar = Calendar.current
        return readArticles.filter { calendar.isDateInToday($0.dateRead) }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Study Stats Bar
            HStack {
                Text("Daily Progress:")
                    .font(.system(.caption, design: .rounded).bold())
                
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < dailyReadCount ? Color.accentColor : Color.primary.opacity(0.1))
                            .frame(width: 20, height: 6)
                    }
                }
                
                Text("\(dailyReadCount)/5 articles")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if dailyReadCount >= 5 {
                    Text("Goal Met! 🎓")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.green)
                }
                
                Button(action: { showHistory = true }) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
            
            // Journal Selector Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Study")
                        .font(.system(.title2, design: .rounded).bold())
                    Text("Medical Journals")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search articles...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
                .frame(width: 250)
                
                Picker("Select Journal", selection: $selectedJournal) {
                    Text("All Journals").tag(Optional<MedicalJournal>.none)
                    Divider()
                    
                    let layers = ["Current Issues"]
                    
                    ForEach(layers, id: \.self) { layer in
                        Section(header: Text(layer)) {
                            ForEach(MedicalJournal.defaults.filter { $0.category == layer }) { journal in
                                Text(journal.name).tag(Optional(journal))
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            if rssService.isFetching {
                VStack {
                    Spacer()
                    ProgressView("Fetching latest articles...")
                    Spacer()
                }
            } else {
                ScrollView {
                    let filteredItems = rssService.items.filter { item in
                        searchText.isEmpty || 
                        item.cleanTitle.localizedCaseInsensitiveContains(searchText) || 
                        item.cleanDescription.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    MasonryVStack(columns: 2, data: filteredItems) { item in
                        StudyArticleCard(item: item, journalName: item.journalName, category: MedicalJournal.defaults.first(where: { $0.name == item.journalName })?.category ?? "")
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if let journal = selectedJournal {
                rssService.fetchFeed(url: journal.rssURL, journalName: journal.name)
            } else {
                rssService.fetchAllFeeds(journals: MedicalJournal.defaults)
            }
        }
        .onChange(of: selectedJournal) { oldValue, newValue in
            if let journal = newValue {
                rssService.fetchFeed(url: journal.rssURL, journalName: journal.name)
            } else {
                rssService.fetchAllFeeds(journals: MedicalJournal.defaults)
            }
        }
        .sheet(isPresented: $showHistory) {
            ReadHistoryView()
        }
        .background(Color(.windowBackgroundColor)) // Professional window background instead of journal theme
    }
}



struct ReadHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadArticle.dateRead, order: .reverse) private var readArticles: [ReadArticle]
    @Environment(\.dismiss) private var dismiss
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(article.title)
                                    .font(.headline)
                                Spacer()
                                Button(action: { article.isFlagged.toggle() }) {
                                    Image(systemName: article.isFlagged ? "star.fill" : "star")
                                        .foregroundColor(article.isFlagged ? .orange : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack {
                                Text(article.publicationName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("•")
                                Text(article.category)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Spacer()
                                Text(article.dateRead.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(filteredArticles[index])
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}


extension View {
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}
#endif
