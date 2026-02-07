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
    
    @State private var showActivity = false
    @State private var selectedDate: Date = Date()
    @State private var viewMode: ScriptureViewMode = .overview
    @State private var showSettings = false
    @State private var isUIVisible = true
    @State private var isSettingsExpanded = false
    @State private var showMissedDays = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            
            if viewMode == .overview {
                overviewLayout
            } else {
                readingLayout
            }
            
            if showActivity && viewMode == .overview {
                Color.black.opacity(0.2)
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
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
            
            if showMissedDays && viewMode == .overview {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showMissedDays = false } }
                
                VStack {
                    Spacer()
                    MissedReadingsDrawer(
                        selectedDate: $selectedDate,
                        viewMode: $viewMode,
                        showMissedDays: $showMissedDays,
                        readDays: readDays,
                        loadReadings: loadReadings
                    )
                    .padding()
                    .background(settings.theme.backgroundColor)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                    .shadow(radius: 20)
                }
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewMode)
        .animation(.spring(), value: showActivity)
        .animation(.easeInOut, value: isUIVisible)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear {
            loadReadings(for: selectedDate)
        }
    }
    
    // MARK: - Overview Layout
    private var overviewLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Fixed Header
                HStack {
                    Button(action: { sidebarSelection = .home }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(settings.theme.textColor.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                    Spacer()
                }
                .padding(.top, 40)
                .zIndex(2)
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 40)
                        
                        VStack(spacing: 32) {
                            // Today's Reading Header
                            VStack(spacing: 8) {
                                Text(selectedDate.formatted(date: .complete, time: .omitted))
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                
                                Text("Today's Readings")
                                    .font(.system(size: 48, weight: .bold, design: .serif))
                                    .foregroundColor(settings.theme.textColor)
                            }
                            
                            let readings = ReadingPlanProvider.shared.getReading(for: selectedDate)
                            VStack(spacing: 12) {
                                ForEach(readings, id: \.self) { reading in
                                    Text(reading)
                                        .font(.system(.title2, design: .serif))
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
                                .font(.system(.title3, design: .rounded).bold())
                                .padding(.horizontal, 60)
                                .padding(.vertical, 20)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 15, x: 0, y: 8)
                            }
                            .buttonStyle(.plain)
                            
                            // Recent Progress Section
                            VStack(spacing: 20) {
                                HStack {
                                    Text("Recent Days")
                                        .font(.system(.subheadline, design: .rounded).bold())
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(maxWidth: 450)
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
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
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.horizontal, 20)
                                }
                                .scrollDisabled(true)
                                .frame(maxWidth: 450)
                                
                                Button(action: { withAnimation { showMissedDays = true } }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("Check Missed Readings")
                                            .font(.system(.caption, design: .rounded).bold())
                                    }
                                    .foregroundColor(.secondary.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            .padding(.top, 24)
                            
                            Button(action: { withAnimation { showActivity = true } }) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Full Activity")
                                }
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 20)
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
            VStack(spacing: 8) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Circle()
                    .fill(isRead ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 50, height: 80)
            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            .cornerRadius(12)
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
                            VStack(spacing: 50) {
                                ForEach(scriptureService.fetchedPassages) { passage in
                                    VStack(spacing: 50) {
                                        Text(passage.reference)
                                            .font(getFont(size: settings.textSize * 1.5))
                                            .underline()
                                            .foregroundColor(settings.theme.textColor)
                                            .frame(maxWidth: .infinity)
                                        
                                        Text(passage.text)
                                            .font(getFont(size: settings.textSize))
                                            .lineSpacing(settings.textSize * 0.45)
                                            .foregroundColor(settings.theme.textColor)
                                    }
                                }
                            }
                            .padding(.horizontal, calculatedPadding)
                            .padding(.top, 140)
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
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isSettingsExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isSettingsExpanded ? "chevron.left" : "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundColor(settings.theme.textColor.opacity(0.3))
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
                            
                            ScriptureTypographyMenu(viewMode: $viewMode)
                                .environmentObject(settings)
                        }
                        .padding(.horizontal, 8)
                        .foregroundColor(settings.theme.textColor.opacity(0.7))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(10)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(settings.theme.textColor.opacity(0.1), lineWidth: 0.5))
                .padding(.top, 40)
                .padding(.leading, 70)
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

// MARK: - Discrete Typography Menu
struct ScriptureTypographyMenu: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var viewMode: ScriptureViewMode
    @State private var isPresented = false
    
    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: "textformat")
                .font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
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
    }
}

// MARK: - Contribution Graph
struct MonthBasedContributionGraph: View {
    @Binding var selectedDate: Date
    let readDays: [ReadDay]
    let mode: CalendarViewMode
    
    private let calendar = Calendar.current
    
    @State private var navigationDate: Date = Date()
    
    var body: some View {
        VStack(spacing: 24) {
            if mode == .month {
                monthView
            } else {
                yearView
            }
        }
        .onAppear {
            navigationDate = selectedDate
        }
    }
    
    private var monthView: some View {
        VStack(spacing: 16) {
            // Month/Year Navigation
            HStack {
                Button(action: { moveMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                
                Text(navigationDate.formatted(.dateTime.month(.wide).year()))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .frame(width: 140)
                
                Button(action: { moveMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { moveYear(by: -1) }) {
                        Image(systemName: "chevron.left.2")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    
                    Text(navigationDate.formatted(.dateTime.year()))
                        .font(.system(.caption, design: .rounded).bold())
                    
                    Button(action: { moveYear(by: 1) }) {
                        Image(systemName: "chevron.right.2")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            
            // Single Month Grid
            let daysInMonth = getDaysInMonth(for: navigationDate)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<42, id: \.self) { index in
                    if index < daysInMonth.count, let date = daysInMonth[index] {
                        let isRead = getStatus(for: date)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isRead ? Color.green.opacity(0.7) : (isSelected ? Color.accentColor : Color.primary.opacity(0.1)))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor, lineWidth: isSelected && isRead ? 2 : 0)
                                )
                            
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected || isRead ? .white : (isToday ? .accentColor : .primary.opacity(0.8)))
                        }
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(width: 32, height: 32)
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var yearView: some View {
        let currentYear = calendar.component(.year, from: navigationDate)
        let months = (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: currentYear, month: month))
        }
        
        return VStack(spacing: 24) {
            // Year Navigation
            HStack {
                Button(action: { moveYear(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                
                Text("\(currentYear)")
                    .font(.system(.headline, design: .rounded).bold())
                
                Button(action: { moveYear(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(months, id: \.self) { month in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(month.formatted(.dateTime.month(.wide)))
                            .font(.system(.caption2, design: .rounded).bold())
                            .foregroundColor(.secondary)
                        
                        let daysInMonth = getDaysInMonth(for: month)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(8), spacing: 2), count: 7), spacing: 2) {
                            ForEach(0..<42, id: \.self) { index in
                                if index < daysInMonth.count, let date = daysInMonth[index] {
                                    let isRead = getStatus(for: date)
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                    
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(isRead ? Color.green.opacity(0.6) : (isSelected ? Color.accentColor : Color.primary.opacity(0.1)))
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 1)
                                                .stroke(Color.accentColor, lineWidth: isSelected && isRead ? 1 : 0)
                                        )
                                        .onTapGesture {
                                            selectedDate = date
                                            navigationDate = month
                                        }
                                } else {
                                    Color.primary.opacity(0.02).frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func moveMonth(by amount: Int) {
        if let newDate = calendar.date(byAdding: .month, value: amount, to: navigationDate) {
            navigationDate = newDate
        }
    }
    
    private func moveYear(by amount: Int) {
        if let newDate = calendar.date(byAdding: .year, value: amount, to: navigationDate) {
            navigationDate = newDate
        }
    }
    
    private func getDaysInMonth(for month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func getStatus(for date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return readDays.contains { $0.dateString == dateString && $0.isRead }
    }
}

// MARK: - Missed Readings Drawer
struct MissedReadingsDrawer: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var selectedDate: Date
    @Binding var viewMode: ScriptureViewMode
    @Binding var showMissedDays: Bool
    let readDays: [ReadDay]
    let loadReadings: (Date) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missed Readings")
                        .font(.system(.title3, design: .serif).bold())
                    Text("Current Year")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                Spacer()
                Button(action: { withAnimation { showMissedDays = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            let missedDays = getMissedDays()
            
            if missedDays.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green.opacity(0.5))
                    Text("All caught up! No missed readings.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                        ForEach(missedDays, id: \.self) { date in
                            Button(action: {
                                withAnimation {
                                    selectedDate = date
                                    loadReadings(date)
                                    viewMode = .reading
                                    showMissedDays = false
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundColor(.secondary)
                                    
                                    let readings = ReadingPlanProvider.shared.getReading(for: date)
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(readings.prefix(2), id: \.self) { reading in
                                            Text(reading)
                                                .font(.system(.subheadline, design: .serif))
                                                .foregroundColor(settings.theme.textColor)
                                                .lineLimit(1)
                                        }
                                        if readings.count > 2 {
                                            Text("+\(readings.count - 2) more")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(.vertical, 24)
        .background(settings.theme.backgroundColor)
    }
    
    private func getMissedDays() -> [Date] {
        var missed: [Date] = []
        let today = Date()
        
        // Ensure we handle current year correctly
        let currentYear = calendar.component(.year, from: today)
        guard let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) else { return [] }
        
        // Find total days from start of year to today
        let components = calendar.dateComponents([.day], from: startOfYear, to: today)
        let daysSinceStart = components.day ?? 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for offset in 0...daysSinceStart {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfYear) else { continue }
            
            // Normalize dates to midnight for comparison
            let normalizedDate = calendar.startOfDay(for: date)
            let normalizedToday = calendar.startOfDay(for: today)
            
            // Don't include today if it hasn't been read yet (it's "current", not "missed")
            if normalizedDate >= normalizedToday { break }
            
            let ds = formatter.string(from: normalizedDate)
            let isRead = readDays.contains { $0.dateString == ds && $0.isRead }
            
            if !isRead {
                missed.append(normalizedDate)
            }
        }
        
        return missed.reversed() // Show most recent first
    }
}
