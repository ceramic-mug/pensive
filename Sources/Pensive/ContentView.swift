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
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showTopMenu = false
    @State private var showBottomToolbar = false
    @State private var sidebarSelection: SidebarItem = .journal
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case journal = "Journal"
        case study = "Study"
        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .journal: return "pencil.line"
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
                let sectionMatch = entry.sections.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
                return contentMatch || sectionMatch
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search entries...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
                .padding()
                
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
                    
                    if sidebarSelection == .journal {
                        Section("Entries") {
                            ForEach(filteredEntries) { entry in
                                Button(action: { selectedEntryID = entry.id }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.system(.caption, design: .rounded).bold())
                                            .foregroundColor(.secondary)
                                        
                                        let displayContent = entry.sections.first?.content ?? entry.content
                                        Text(displayContent.isEmpty ? "New Day" : displayContent.replacingOccurrences(of: "\n", with: " "))
                                            .lineLimit(1)
                                            .font(.system(.body, design: .rounded))
                                        
                                        if entry.sections.count > 1 {
                                            Text("\(entry.sections.count) sections")
                                                .font(.system(.caption2, design: .rounded))
                                                .foregroundColor(.accentColor.opacity(0.8))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(selectedEntryID == entry.id ? Color.accentColor.opacity(0.1) : Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("Pensive")
        } detail: {
            if sidebarSelection == .journal {
                JournalView(
                    entries: entries,
                    selectedEntryID: $selectedEntryID,
                    showBottomToolbar: $showBottomToolbar,
                    columnVisibility: $columnVisibility,
                    showTopMenu: $showTopMenu,
                    addNewEntry: addNewEntry
                )
            } else {
                StudyView()
            }
        }
            .background(
                Group {
                    Button("") { settings.textSize = min(72, settings.textSize + 2) }
                        .keyboardShortcut("+", modifiers: .command)
                    Button("") { settings.textSize = max(12, settings.textSize - 2) }
                        .keyboardShortcut("-", modifiers: .command)
                    Button("") { withAnimation { settings.isDistractionFree.toggle() } }
                        .keyboardShortcut("d", modifiers: .command)
                }
                .opacity(0)
            )
            .onChange(of: settings.isDistractionFree) { oldValue, newValue in
                if sidebarSelection == .journal {
                    withAnimation {
                        columnVisibility = newValue ? .detailOnly : .all
                    }
                }
            }
            .onChange(of: sidebarSelection) { oldValue, newValue in
                if newValue == .journal {
                    autoSelectTodayEntry()
                }
                
                // Exit distraction free automatically if switching to Study
                if newValue == .study && settings.isDistractionFree {
                    withAnimation {
                        settings.isDistractionFree = false
                        columnVisibility = .all
                    }
                }
            }
            .toolbar(.hidden, for: .windowToolbar)
            .onAppear {
                autoSelectTodayEntry()
            }
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
            newEntry.sections.append(firstSection)
            
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
            existingEntry.sections.append(newSection)
            selectedEntryID = existingEntry.id
        } else {
            autoSelectTodayEntry()
        }
    }
    
    private func migrateLegacyContent(for entry: JournalEntry) {
        if !entry.content.isEmpty && entry.sections.isEmpty {
            let migratedSection = JournalSection(content: entry.content, timestamp: entry.date)
            entry.sections.append(migratedSection)
            entry.content = "" // Clear after migration
        }
    }
}

struct JournalView: View {
    let entries: [JournalEntry]
    @Binding var selectedEntryID: UUID?
    @Binding var showBottomToolbar: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showTopMenu: Bool
    let addNewEntry: () -> Void
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let entryID = selectedEntryID, let entry = entries.first(where: { $0.id == entryID }) {
                DetailView(entry: entry, showBottomToolbar: $showBottomToolbar)
            } else {
                ContentUnavailableView {
                    Label("Select an Entry", systemImage: "pencil.line")
                } description: {
                    Text("Choose a journal entry from the sidebar to start writing.")
                } actions: {
                    Button(action: addNewEntry) {
                        Text("Create New Entry")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settings.theme.backgroundColor)
            }
            
            // Floating controls are ONLY in Journal mode
            TopLeftControls(
                columnVisibility: $columnVisibility,
                selectedEntryID: $selectedEntryID,
                showTopMenu: $showTopMenu,
                entries: entries,
                addNewEntry: addNewEntry
            )
        }
    }
}

struct StudyView: View {
    var body: some View {
        MedicalJournalBrowserView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DetailView: View {
    @Bindable var entry: JournalEntry
    @EnvironmentObject var settings: AppSettings
    @Binding var showBottomToolbar: Bool
    
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        ForEach(entry.sections.sorted(by: { $0.timestamp < $1.timestamp })) { section in
                            SectionEditor(
                                section: section,
                                fontName: settings.font.name,
                                fontSize: settings.textSize,
                                textColor: settings.theme.textColor,
                                selectionColor: settings.theme.selectionColor,
                                horizontalPadding: settings.horizontalPadding,
                                parentEntry: entry
                            )
                        }
                        
                        .padding(.horizontal, settings.horizontalPadding + 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            if !entry.content.isEmpty && entry.sections.isEmpty {
                let migratedSection = JournalSection(content: entry.content, timestamp: entry.date)
                entry.sections.append(migratedSection)
                entry.content = ""
            }
        }
    }
    
    private var headerFont: Font {
        switch settings.font {
        case .sans: return .system(.headline, design: .rounded)
        case .serif: return .system(.headline, design: .serif)
        case .mono: return .system(.headline, design: .monospaced)
        }
    }
}

struct SectionEditor: View {
    @Bindable var section: JournalSection
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    var parentEntry: JournalEntry
    
    @State private var isPickerPresented = false
    @State private var pickerQuery = ""
    @State private var pickerPosition: CGPoint = .zero
    @State private var selectedIndex = 0
    @State private var textHeight: CGFloat = 100
    @State private var isCollapsed = false
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack(spacing: 8) {
                // Time / Timestamp
                Text(section.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.4))
                
                if isCollapsed && !section.content.isEmpty {
                    Text(section.content.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(textColor.opacity(0.3))
                        .lineLimit(1)
                        .transition(.opacity)
                }
                
                Spacer()
                
                if isHovering || isCollapsed {
                    HStack(spacing: 12) {
                        if !isCollapsed {
                            Button(role: .destructive) {
                                if let index = parentEntry.sections.firstIndex(where: { $0.id == section.id }) {
                                    parentEntry.sections.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundColor(.red.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isCollapsed.toggle() } }) {
                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding + 20)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCollapsed {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isCollapsed.toggle() }
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            
            if !isCollapsed {
                NativeTextView(
                    text: $section.content,
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
                .frame(height: textHeight)
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if isPickerPresented && !isCollapsed {
                SymbolPicker(query: $pickerQuery, selectedIndex: $selectedIndex) { item in
                    insertSymbol(item)
                }
                .padding(.top, 40)
                .padding(.leading, horizontalPadding + 40)
                .transition(.scale(0.9).combined(with: .opacity))
            }
        }
    }
    
    // ... Picker methods remain the same
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
        if let range = section.content.range(of: trigger, options: .backwards) {
            section.content.replaceSubrange(range, with: item.symbol)
            isPickerPresented = false
            pickerQuery = ""
        }
    }
}

// Top-level controls that can be persistent or hover-based
struct TopLeftControls: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var selectedEntryID: UUID?
    @Binding var showTopMenu: Bool
    @State private var isMenuExpanded = false // Track expansion state here
    let entries: [JournalEntry]
    let addNewEntry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Anchor: Settings Menu
            if let entryID = selectedEntryID, let entry = entries.first(where: { $0.id == entryID }) {
                ExpandingSettingsMenu(entry: entry, isExpanded: $isMenuExpanded) {
                    selectedEntryID = nil
                }
                .opacity(settings.isDistractionFree && !showTopMenu ? 0.4 : 1.0)
            }

            // Other buttons revealed on hover or if not in focus mode
            if !settings.isDistractionFree || showTopMenu {
                HStack(spacing: 12) {
                    TopLeftButton(icon: "sidebar.left", help: "Toggle Sidebar") {
                        withAnimation {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    }

                    TopLeftButton(icon: "plus", help: "New Entry") {
                        addNewEntry()
                    }

                    if settings.isDistractionFree {
                        TopLeftButton(icon: "eye.slash", help: "Exit Focus Mode") {
                            withAnimation { settings.isDistractionFree = false }
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.leading, 16)
        .padding(.top, 4)
        .padding(.trailing, 120) // Generous hit area
        .padding(.bottom, 100)
        .background(
            Color.white.opacity(0.001)
                .contentShape(Rectangle())
        )
        .onHover { hovering in
            if settings.isDistractionFree && !isMenuExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showTopMenu = hovering
                }
            }
        }
    }
}

struct TopLeftButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ExpandingSettingsMenu: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Bindable var entry: JournalEntry
    @Binding var isExpanded: Bool
    @State private var isTypographyPresented = false
    var onDeleted: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            toggleButton
            if isExpanded {
                expandedContent
            }
        }
        .background(isExpanded ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        .clipShape(Capsule())
    }

    private var toggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            Image(systemName: isExpanded ? "chevron.left" : "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .foregroundColor(isExpanded ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Collapse Settings" : "Expand Settings")
    }

    private var expandedContent: some View {
        HStack(spacing: 2) {
            typographyMenu
            themeMenu
            layoutToggle
            dangerousActionsMenu
        }
        .padding(.trailing, 4)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var typographyMenu: some View {
        Button(action: { isTypographyPresented.toggle() }) {
            Image(systemName: "textformat")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
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
                
                Text("Text Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button(action: { settings.textSize = max(12, settings.textSize - 2) }) {
                        Image(systemName: "textformat.size.smaller")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Text("\(Int(settings.textSize))")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .frame(width: 30)
                    
                    Button(action: { settings.textSize = min(72, settings.textSize + 2) }) {
                        Image(systemName: "textformat.size.larger")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 200)
        }
        .help("Typography")
    }

    private var themeMenu: some View {
        Menu {
            ForEach(AppTheme.allCases) { theme in
                Button(action: { settings.theme = theme }) {
                    HStack {
                        Text(theme.rawValue.capitalized)
                        if settings.theme == theme {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Theme")
    }

    private var layoutToggle: some View {
        Button(action: { withAnimation { settings.isDistractionFree.toggle() } }) {
            Image(systemName: settings.isDistractionFree ? "eye" : "eye.slash")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(settings.isDistractionFree ? "Exit Focus Mode" : "Enter Focus Mode")
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
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
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
                List {
                    let filteredItems = rssService.items.filter { item in
                        searchText.isEmpty || 
                        item.cleanTitle.localizedCaseInsensitiveContains(searchText) || 
                        item.cleanDescription.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    ForEach(filteredItems) { item in
                        RSSItemRow(item: item, journalName: item.journalName, category: MedicalJournal.defaults.first(where: { $0.name == item.journalName })?.category ?? "")
                            .listRowSeparator(.hidden)
                            .padding(.horizontal, 8)
                    }
                }
                .listStyle(.plain)
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

struct RSSItemRow: View {
    @Environment(\.modelContext) private var modelContext
    let item: RSSItem
    let journalName: String
    let category: String
    @Query private var readArticles: [ReadArticle]
    @State private var isExpanded = false
    
    var isRead: Bool {
        readArticles.contains { $0.url == item.link }
    }
    
    var isStarred: Bool {
        readArticles.first(where: { $0.url == item.link })?.isFlagged ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 200)
                        .clipped()
                        .cornerRadius(8)
                } placeholder: {
                    Color.primary.opacity(0.05)
                        .frame(height: 200)
                }
                .padding(.bottom, 4)
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.cleanTitle)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(isRead ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if !journalName.isEmpty {
                            Text(journalName)
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.accentColor)
                            
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        
                        if !item.creator.isEmpty {
                            Text(item.creator)
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(item.pubDate)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: toggleRead) {
                    Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isRead ? .green : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                
                Button(action: toggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundColor(isStarred ? .orange : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            
            if !item.cleanDescription.isEmpty {
                Text(item.cleanDescription)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(isExpanded ? nil : 3)
                    .padding(.vertical, 4)
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Text(isExpanded ? "Show Less" : "Read More")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
                Button(action: {
                    markAsRead()
                    if let url = URL(string: item.link) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Open Article", systemImage: "safari")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if let doi = item.doi {
                    Text("DOI: \(doi)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.leading, 8)
                }
            }
        .padding()
        .background(Color.white.opacity(0.001)) // For selection background
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRead ? Color.green.opacity(0.2) : Color.primary.opacity(0.05), lineWidth: 1)
        )
        .listRowBackground(Color.clear)
    }
    
    private func markAsRead() {
        if !isRead {
            let newRead = ReadArticle(url: item.link, title: item.cleanTitle, category: category, publicationName: journalName)
            modelContext.insert(newRead)
        }
    }
    
    private func toggleRead() {
        if isRead {
            if let existing = readArticles.first(where: { $0.url == item.link }) {
                modelContext.delete(existing)
            }
        } else {
            markAsRead()
        }
    }
    
    private func toggleStar() {
        if let existing = readArticles.first(where: { $0.url == item.link }) {
            existing.isFlagged.toggle()
        } else {
            let newRead = ReadArticle(url: item.link, title: item.cleanTitle, category: category, publicationName: journalName)
            newRead.isFlagged = true
            modelContext.insert(newRead)
        }
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

#endif
