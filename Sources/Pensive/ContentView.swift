#if os(macOS)
import SwiftUI
import SwiftData
import MapKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    
    @State private var selectedEntryID: UUID?
    @State private var searchText: String = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showTopMenu = false
    @State private var showBottomToolbar = false
    
    var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        } else {
            return entries.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
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
                
                List(selection: $selectedEntryID) {
                    ForEach(filteredEntries) { entry in
                        NavigationLink(value: entry.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Text(entry.content.isEmpty ? "New Entry" : entry.content.replacingOccurrences(of: "\n", with: " "))
                                    .lineLimit(1)
                                    .font(.system(.body, design: .rounded))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("Pensive")
            .toolbar {
                ToolbarItem {
                    Button(action: addNewEntry) {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
        } detail: {
            ZStack(alignment: .topLeading) {
                if let entryID = selectedEntryID, let entry = entries.first(where: { $0.id == entryID }) {
                    DetailView(entry: entry, showBottomToolbar: $showBottomToolbar)
                } else {
                    ContentUnavailableView("Select an Entry", systemImage: "pencil.line", description: Text("Choose a journal entry from the sidebar to start writing."))
                }
                
                // Stable Top-Left Edge Reveal
                if settings.isDistractionFree {
                    Color.clear
                        .frame(width: 150, height: 100)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showTopMenu = hovering
                            }
                        }
                        .overlay(
                            HStack {
                                Button(action: { 
                                    withAnimation {
                                        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                                    }
                                }) {
                                    Image(systemName: "sidebar.left")
                                        .font(.system(size: 16, weight: .medium))
                                        .padding(12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: addNewEntry) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                        .padding(12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(20)
                            .scaleEffect(showTopMenu ? 1 : 0.8)
                            .opacity(showTopMenu ? 1 : 0)
                            , alignment: .topLeading
                        )
                }
            }
        }
        .toolbar(settings.isDistractionFree ? .hidden : .visible, for: .windowToolbar)
        .onChange(of: settings.isDistractionFree) { oldValue, newValue in
            withAnimation {
                columnVisibility = newValue ? .detailOnly : .all
            }
        }
    }
    
    private func addNewEntry() {
        let newEntry = JournalEntry()
        modelContext.insert(newEntry)
        DispatchQueue.main.async {
            selectedEntryID = newEntry.id
        }
    }
}

struct DetailView: View {
    @Bindable var entry: JournalEntry
    @EnvironmentObject var settings: AppSettings
    @Binding var showBottomToolbar: Bool
    
    // Picker State
    @State private var isPickerPresented = false
    @State private var pickerQuery = ""
    @State private var pickerPosition: CGPoint = .zero
    @State private var selectedIndex = 0
    
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
                        .padding(.bottom, 20)
                    Spacer()
                }
                
                NativeTextView(
                    text: $entry.content,
                    fontName: settings.font.name,
                    fontSize: settings.textSize,
                    textColor: settings.theme.textColor,
                    selectionColor: settings.theme.selectionColor,
                    horizontalPadding: settings.horizontalPadding,
                    isPickerPresented: $isPickerPresented,
                    pickerQuery: $pickerQuery,
                    pickerPosition: $pickerPosition,
                    onCommand: handlePickerCommand
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // Stable Bottom Edge Reveal Logic
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    Color.clear
                        .frame(height: showBottomToolbar ? 150 : 80)
                        .contentShape(Rectangle())
                    
                    if !settings.isDistractionFree || showBottomToolbar {
                        FloatingToolbar(entry: entry)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 24)
                    }
                }
                .onHover { hovering in
                    if hovering != showBottomToolbar {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showBottomToolbar = hovering
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerQuery) { oldValue, newValue in
            selectedIndex = 0
        }
        .overlay(alignment: .topLeading) {
            if isPickerPresented {
                SymbolPicker(query: $pickerQuery, selectedIndex: $selectedIndex) { item in
                    insertSymbol(item)
                }
                .padding(.top, 40) // Spacing from top of text
                .padding(.leading, 80 + horizontalPadding) // Rough horizontal alignment
                .transition(.scale(0.9).combined(with: .opacity))
            }
        }
    }
    
    // Pass horizontal padding for layout alignment
    private var horizontalPadding: CGFloat {
        settings.horizontalPadding
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
        case .confirm:
            if let item = getSelectedItem() {
                insertSymbol(item)
                return true
            }
        case .complete:
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
        // Find the "/" + query in the text and replace it
        let trigger = "/" + pickerQuery
        if let range = entry.content.range(of: trigger, options: .backwards) {
            entry.content.replaceSubrange(range, with: item.symbol)
            isPickerPresented = false
            pickerQuery = ""
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

struct FloatingToolbar: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Bindable var entry: JournalEntry
    @State private var locationManager = LocationManager()
    @State private var showMap = false
    
    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 12) {
                ToolbarIconButton(icon: "trash", color: .red) {
                    modelContext.delete(entry)
                }
                ToolbarIconButton(icon: "location") {
                    locationManager.requestLocation()
                }
                .onChange(of: locationManager.location) { old, new in
                    if let location = new {
                        entry.latitude = location.coordinate.latitude
                        entry.longitude = location.coordinate.longitude
                        entry.locationName = locationManager.locationName
                    }
                }
                
                if entry.latitude != nil {
                    ToolbarIconButton(icon: "map", color: showMap ? .accentColor : .primary) {
                        showMap.toggle()
                    }
                    .popover(isPresented: $showMap) {
                        MiniMapView(latitude: entry.latitude!, longitude: entry.longitude!)
                            .frame(width: 300, height: 200)
                    }
                }
            }
            
            Divider().frame(height: 20)
            
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Slider(value: $settings.horizontalPadding, in: 20...400)
                    .frame(width: 80)
            }
            
            Divider().frame(height: 20)
            
            HStack(spacing: 12) {
                Picker("", selection: $settings.font) {
                    Text("Sans").tag(AppFont.sans)
                    Text("Serif").tag(AppFont.serif)
                    Text("Mono").tag(AppFont.mono)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            Divider().frame(height: 20)
            
            HStack(spacing: 16) {
                ForEach(AppTheme.allCases) { theme in
                    Circle()
                        .fill(theme.backgroundColor)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.primary.opacity(settings.theme == theme ? 0.5 : 0.1), lineWidth: 2))
                        .onTapGesture {
                            withAnimation { settings.theme = theme }
                        }
                }
            }
            
            Divider().frame(height: 20)
            
            HStack(spacing: 12) {
                ToolbarIconButton(icon: settings.isDistractionFree ? "eye" : "eye.slash") {
                    withAnimation { settings.isDistractionFree.toggle() }
                }
                .help(settings.isDistractionFree ? "Show Menu" : "Hide Menu")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

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

#endif
