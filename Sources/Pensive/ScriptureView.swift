import SwiftUI
import SwiftData

enum ScriptureViewMode {
    case overview
    case reading
}

enum CalendarViewMode {
    case month
    case year
}

struct ScriptureView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scriptureService = ScriptureService()
    @Query(sort: \ReadDay.dateString, order: .reverse) private var readDays: [ReadDay]
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var selectedDate: Date = Date()
    @State private var viewMode: ScriptureViewMode = .overview
    @State private var showSettings = false
    @State private var isUIVisible = true
    @State private var isSettingsExpanded = false
    @State private var isTypographyPresented = false
    
    private let calendar = Calendar.current
    
    private var isCompact: Bool {
        sizeClass == .compact
    }
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            
            if viewMode == .overview {
                overviewLayout
            } else {
                readingLayout
            }
            
            
        }
        .sheet(isPresented: $isTypographyPresented) {
            #if os(iOS)
            NavigationView {
                ScriptureSettingsContent()
                    .environmentObject(settings)
                    .navigationTitle("Typography")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { isTypographyPresented = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #else
            ScriptureSettingsContent()
                .padding()
                .frame(width: 250)
                .environmentObject(settings)
            #endif
        }
        .animation(.spring(), value: viewMode)
        .animation(.easeInOut, value: isUIVisible)
        #if os(iOS)
        .navigationBarHidden(viewMode == .reading && !isUIVisible)
        .toolbar((viewMode == .reading && !isUIVisible) || (viewMode == .reading && isSettingsExpanded) ? .hidden : .visible, for: .tabBar)
        .statusBar(hidden: viewMode == .reading && !isUIVisible)
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear {
            loadReadings(for: selectedDate)
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetTab)) { notification in
            if let tab = notification.object as? ContentView.SidebarItem, tab == .scripture {
                withAnimation {
                    viewMode = .overview
                    isUIVisible = true
                    showSettings = false
                }
            }
        }
    }
    
    // MARK: - Overview Layout
    private var overviewLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                UnifiedModuleHeader(
                    title: "Scripture",
                    subtitle: selectedDate.formatted(date: .long, time: .omitted),
                    onBack: { sidebarSelection = .home },
                    onShowSettings: { showSettings = true }
                )
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 80) // Push content down below fixed header
                        
                        VStack(spacing: 32) {
                            // Today's Reading Section (iOS Card Style)
                            VStack(spacing: 24) {
                                VStack(spacing: 8) {
                                    Text("Today's Readings")
                                        .font(.system(size: sizeClass == .compact ? 24 : 48, weight: .bold, design: .serif))
                                        .foregroundColor(settings.theme.textColor)
                                        .multilineTextAlignment(.center)
                                }
                                
                                let readings = ReadingPlanProvider.shared.getReading(for: selectedDate)
                                VStack(spacing: 8) {
                                    ForEach(readings, id: \.self) { reading in
                                        Text(reading)
                                            .font(.system(size: sizeClass == .compact ? 18 : 22, weight: .medium, design: .serif))
                                            .foregroundColor(settings.theme.textColor.opacity(0.8))
                                    }
                                }
                                
                                Button(action: { 
                                    loadReadings(for: selectedDate)
                                    viewMode = .reading 
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "book.fill")
                                        Text("Read Now")
                                    }
                                    .font(.system(.headline, design: .rounded).bold())
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 32)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: 400)
                            .background(settings.theme.textColor.opacity(0.04))
                            .cornerRadius(24)
                            .padding(.horizontal, 20)
                            
                            // Recent Progress Section
                            VStack(spacing: 20) {
                                HStack {
                                    Text("Recent Days")
                                        .font(.system(.subheadline, design: .rounded).bold())
                                        .foregroundColor(.secondary.opacity(0.6))
                                    Spacer()
                                }
                                .frame(maxWidth: sizeClass == .compact ? .infinity : 450)
                                .padding(.horizontal, 16)
                                
                                // ScrollView removed for fixed center on iOS
                                HStack(spacing: 5) {
                                    ForEach(0..<7) { offset in
                                        let date = calendar.date(byAdding: .day, value: -6 + offset, to: Date())!
                                        DayReadingCard(
                                            date: date,
                                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                            isRead: hasRead(date),
                                            action: {
                                                withAnimation {
                                                    selectedDate = date
                                                    loadReadings(for: date)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.top, 10)
                            
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }
    
    private func hasRead(_ date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let ds = formatter.string(from: date)
        return readDays.contains { $0.dateString == ds && $0.isRead }
    }
}

// MARK: - Day Reading Card
struct DayReadingCard: View {
    let date: Date
    let isSelected: Bool
    let isRead: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Circle()
                    .fill(isRead ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 38, height: 68)
            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.04))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

extension ScriptureView {

    
    // MARK: - Reading Layout
    private var readingLayout: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        let calculatedPadding = geometry.size.width * settings.marginPercentage
                        
                        if scriptureService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 200)
                        } else {
                            VStack(spacing: 24) { // Reduced spacing between passages
                                ForEach(scriptureService.fetchedPassages) { passage in
                                    VStack(alignment: .leading, spacing: 16) { // Reduced spacing between reference and text
                                        Text(passage.reference)
                                            .font(getFont(size: settings.textSize * 1.2).bold()) // Use .bold() modifier instead
                                            .foregroundColor(settings.theme.textColor.opacity(0.6))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Text(passage.text(isCompact: sizeClass == .compact))
                                            .font(getFont(size: settings.textSize))
                                            .lineSpacing(settings.lineSpacing)
                                            .foregroundColor(settings.theme.textColor)
                                            // For poetry, we might want a different alignment or padding if NOT wrapped
                                            .padding(.leading, (passage.isPoetic && sizeClass != .compact) ? 12 : 0)
                                    }
                                    .padding(.bottom, 24) // Spacing after each passage
                                }
                            }
                            .padding(.horizontal, calculatedPadding)
                            .padding(.top, sizeClass == .compact ? 60 : 140) // Reduced top padding on iOS
                            .padding(.bottom, 120)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isUIVisible.toggle()
                                }
                            }
                            
                            // Bottom sentinel for auto-marking
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    if !isTodayRead {
                                        markAsRead()
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Floating Toolbar (Matches Journal)
            if isUIVisible {
                HStack(spacing: 0) {
                    // Settings Toggle
                    Button(action: {
                        #if os(iOS)
                        isTypographyPresented.toggle() // Open sheet directly on iOS
                        #else
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isSettingsExpanded.toggle()
                        }
                        #endif
                    }) {
                        Image(systemName: isSettingsExpanded ? "chevron.left" : "textformat.size")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(settings.theme.textColor.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if isSettingsExpanded {
                        HStack(spacing: 12) {
                            // Home Button
                            Button(action: { 
                                viewMode = .overview 
                                isUIVisible = true
                            }) {
                                Image(systemName: "house")
                                    .font(.system(size: 15))
                                    .foregroundColor(settings.theme.textColor.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Back to Overview")
                            
                            Divider().frame(height: 16)
                            
                            HStack(spacing: 8) {
                                Button(action: { settings.textSize = max(12, settings.textSize - 1) }) {
                                    Image(systemName: "textformat.size.smaller")
                                }
                                .buttonStyle(.plain)
                                Button(action: { settings.textSize = min(72, settings.textSize + 1) }) {
                                    Image(systemName: "textformat.size.larger")
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack(spacing: 6) {
                                ForEach(AppTheme.allCases) { theme in
                                    Button(action: { settings.theme = theme }) {
                                        Circle()
                                            .fill(theme.backgroundColor)
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                Circle().stroke(settings.theme.textColor.opacity(settings.theme == theme ? 0.8 : 0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            ScriptureTypographyMenu(viewMode: $viewMode, isPresented: $isTypographyPresented)
                                .environmentObject(settings)
                        }
                        .padding(.trailing, 12)
                        .padding(.leading, 4)
                        .foregroundColor(settings.theme.textColor.opacity(0.7))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .background(
                    Capsule()
                        .fill(settings.theme.backgroundColor.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                )
                .padding(.top, sizeClass == .compact ? 0 : 40)
                .padding(sizeClass == .compact ? .trailing : .leading, sizeClass == .compact ? 20 : 70) 
                .frame(maxWidth: .infinity, alignment: sizeClass == .compact ? .topTrailing : .leading) // Top trailing on iOS
                .padding(.top, sizeClass == .compact ? 20 : 0)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Font Helper
    private func getFont(size: Double) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size)
        case .serif:
            return .custom("Iowan Old Style", size: size)
        case .mono:
            return .system(size: size, design: .monospaced)
        }
    }
    
    // MARK: - Helpers
    private var isTodayRead: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)
        return readDays.contains { $0.dateString == dateString && $0.isRead }
    }
    
    private func loadReadings(for date: Date) {
        let readings = ReadingPlanProvider.shared.getReading(for: date)
        scriptureService.fetchScripture(passages: readings, apiKey: settings.esvApiKey)
    }
    
    private func moveDate(by days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            loadReadings(for: newDate)
        }
    }
    
    private func markAsRead() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)
        
        if let existing = readDays.first(where: { $0.dateString == dateString }) {
            if !existing.isRead {
                existing.isRead = true
                try? modelContext.save()
            }
        } else {
            let newReadDay = ReadDay(dateString: dateString)
            modelContext.insert(newReadDay)
            try? modelContext.save()
        }
    }
}

struct ScriptureTypographyMenu: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var viewMode: ScriptureViewMode
    @Binding var isPresented: Bool
    
    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: "textformat")
                .font(.system(size: 13))
        }
        .buttonStyle(.plain)
    }
}

struct ScriptureSettingsContent: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        List {
            Section("Font") {
                Picker("Font family", selection: $settings.font) {
                    ForEach(AppFont.allCases) { font in
                        Text(font.rawValue.capitalized).tag(font)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            
            Section("Layout") {
                // Combine into more compact rows
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "textformat.size")
                            .frame(width: 24)
                        Slider(value: $settings.textSize, in: 12...72, step: 1)
                        Text("\(Int(settings.textSize))")
                            .font(.system(.subheadline, design: .rounded).monospacedDigit())
                            .frame(width: 32, alignment: .trailing)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.left.and.right")
                            .frame(width: 24)
                        Slider(value: $settings.marginPercentage, in: 0...0.45, step: 0.05)
                        Text("\(Int((1.0 - settings.marginPercentage * 2) * 100))%")
                            .font(.system(.subheadline, design: .rounded).monospacedDigit())
                            .frame(width: 32, alignment: .trailing)
                    }
                    
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .frame(width: 24)
                        Slider(value: $settings.lineSpacing, in: 0...40, step: 1)
                        Text("\(Int(settings.lineSpacing))")
                            .font(.system(.subheadline, design: .rounded).monospacedDigit())
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListHeaderHeight, 1)
        #endif
    }
}

// MARK: - Contribution Graph
