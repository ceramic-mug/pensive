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
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scriptureService = ScriptureService()
    @Query(sort: \ReadDay.dateString, order: .reverse) private var readDays: [ReadDay]
    
    @State private var selectedDate: Date = Date()
    @State private var viewMode: ScriptureViewMode = .overview
    @State private var calendarMode: CalendarViewMode = .month
    @State private var isSettingsExpanded = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            
            if viewMode == .overview {
                overviewLayout
            } else {
                readingLayout
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewMode)
        .onAppear {
            loadReadings(for: selectedDate)
        }
    }
    
    // MARK: - Overview Layout
    private var overviewLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 48) {
                    // 1. Today's Reading Header (Top & Center)
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(selectedDate.formatted(date: .complete, time: .omitted))
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1.5)
                            
                            Text("Today's Readings")
                                .font(.system(.largeTitle, design: .rounded).bold())
                                .foregroundColor(settings.theme.textColor)
                        }
                        
                        let readings = ReadingPlanProvider.shared.getReading(for: selectedDate)
                        VStack(spacing: 12) {
                            ForEach(readings, id: \.self) { reading in
                                HStack {
                                    Image(systemName: "book.closed")
                                        .font(.subheadline)
                                    Text(reading)
                                        .font(.system(.title3, design: .rounded))
                                }
                                .foregroundColor(settings.theme.textColor.opacity(0.8))
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Button(action: { viewMode = .reading }) {
                            HStack(spacing: 12) {
                                Image(systemName: "book.fill")
                                Text("Read Now")
                            }
                            .font(.system(.headline, design: .rounded).bold())
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 80)
                    .frame(maxWidth: .infinity)
                    
                    // 2. Reading Progress Section (Secondary)
                    VStack(spacing: 24) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reading Progress")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(settings.theme.textColor)
                                
                                Text(isTodayRead ? "Reading completed for this day" : "Reading pending")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // View Mode Toggle
                            Picker("View", selection: $calendarMode) {
                                Text("Month").tag(CalendarViewMode.month)
                                Text("Year").tag(CalendarViewMode.year)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                            
                            Button(action: markAsRead) {
                                Image(systemName: isTodayRead ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isTodayRead ? .green : .secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal)
                        
                        MonthBasedContributionGraph(
                            selectedDate: $selectedDate,
                            readDays: readDays,
                            mode: calendarMode
                        )
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 20)
                }
                .maxInternalWidth(800)
            }
        }
    }
    
    // MARK: - Reading Layout
    private var readingLayout: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 100) {
                        let calculatedPadding = geometry.size.width * settings.marginPercentage
                        
                        if scriptureService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 200)
                        } else {
                            ForEach(scriptureService.fetchedPassages) { passage in
                                VStack(spacing: 48) {
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
                            .padding(.horizontal, calculatedPadding)
                            .padding(.top, 140)
                            .padding(.bottom, 120)
                            
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
                        Button(action: { viewMode = .overview }) {
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
                .pickerStyle(.segmented)
                
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

extension View {
    func maxInternalWidth(_ width: CGFloat) -> some View {
        self.frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .padding(.horizontal, max(0, (NSScreen.main?.visibleFrame.width ?? 1200 - width) / 4))
    }
}

struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
