import SwiftUI
import SwiftData

enum StudyViewMode {
    case home
    case dashboard
}

struct StudyView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @State private var viewMode: StudyViewMode = .home
    @State private var selectedFeed: RSSFeed? = nil

    enum StudySortOrder: String, CaseIterable, Identifiable {
        case recent = "Most Recent"
        case alphabeticalTitle = "Title A-Z"
        case alphabeticalAuthor = "Author A-Z"
        case random = "Random Shuffle"
        var id: String { self.rawValue }
    }

    var body: some View {
        Group {
            if viewMode == .home {
                StudyHomeView(
                    sidebarSelection: $sidebarSelection,
                    onSelectFeed: { feed in
                        self.selectedFeed = feed
                        withAnimation {
                            viewMode = .dashboard
                        }
                    }
                )
            } else {
                StudyDashboardView(
                    sidebarSelection: $sidebarSelection,
                    selectedFeed: selectedFeed,
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
        .onReceive(NotificationCenter.default.publisher(for: .resetTab)) { notification in
            if let tab = notification.object as? ContentView.SidebarItem, tab == .study {
                withAnimation {
                    viewMode = .home
                }
            }
        }
    }
}

struct StudyDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var rssService: RSSService
    @EnvironmentObject var settings: AppSettings
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @Query private var allFeeds: [RSSFeed]
    
    var selectedFeed: RSSFeed?
    var onBack: () -> Void
    
    @State private var selectedJournal: RSSFeed? = nil
    @State private var searchText: String = ""
    @State private var sortOrder: StudyView.StudySortOrder = .recent
    @State private var showHistory = false
    @State private var isShuffling = false
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if sizeClass == .compact {
                    compactHeader
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                } else {
                    StudyHeader(
                        sidebarSelection: $sidebarSelection,
                        selectedJournal: $selectedJournal,
                        searchText: $searchText,
                        sortOrder: $sortOrder,
                        showHistory: $showHistory,
                        isShuffling: $isShuffling,
                        onBack: onBack
                    )
                }
                
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
            
            if allFeeds.isEmpty {
                // If feeds set is empty, insert defaults and fetch from them directly
                for feed in RSSFeed.defaults {
                    modelContext.insert(feed)
                }
                // Use the defaults directly for the initial fetch (don't wait for SwiftData)
                rssService.fetchAllFeeds(feeds: RSSFeed.defaults)
            } else {
                applyFeedSelection()
            }
        }
        .onChange(of: allFeeds) { oldVal, newVal in
            // Re-apply selection when feeds become available (e.g., after CloudKit sync)
            if oldVal.isEmpty && !newVal.isEmpty && selectedJournal == nil {
                applyFeedSelection()
            }
        }
        .onChange(of: rssService.items.count) { _, _ in
            rssService.sortItems(by: sortOrder)
        }
        .onChange(of: sortOrder) { _, newValue in
            rssService.sortItems(by: newValue)
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
            // Use allFeeds if available, otherwise fall back to defaults
            let feedsToFetch = allFeeds.isEmpty ? RSSFeed.defaults : Array(allFeeds)
            rssService.fetchAllFeeds(feeds: feedsToFetch)
        }
        rssService.sortItems(by: sortOrder)
    }
}

extension StudyDashboardView {
    private var compactHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Study")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundColor(settings.theme.textColor)
                
                if let journal = selectedJournal {
                    Text(journal.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("All Sources")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(StudyView.StudySortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    Divider()
                    Picker("Filter Status", selection: $settings.studyFilter) {
                        Text("All").tag(StudyFilter.all)
                        Text("Unread").tag(StudyFilter.unread)
                    }
                    Divider()
                    Picker("Layout Style", selection: $settings.studyLayoutStyle) {
                        Label("List", systemImage: "list.bullet").tag(StudyLayoutStyle.list)
                        #if os(macOS)
                        Label("Grid", systemImage: "square.grid.2x2").tag(StudyLayoutStyle.grid)
                        #endif
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(settings.theme.backgroundColor)
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
    @Binding var sortOrder: StudyView.StudySortOrder
    @Binding var showHistory: Bool
    @Binding var isShuffling: Bool
    var onBack: () -> Void
    @State private var showFeedManager = false
    @Query private var readArticles: [ReadArticle]
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var dailyReadCount: Int {
        let calendar = Calendar.current
        return readArticles.filter { calendar.isDateInToday($0.dateRead) }.count
    }

    var body: some View {
        VStack(spacing: sizeClass == .compact ? 16 : 12) {
            if sizeClass == .compact {
                VStack(spacing: 12) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .bold))
                                .padding(8)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Text(selectedJournal?.name ?? "Study")
                            .font(.system(.headline, design: .serif).bold())
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text("\(dailyReadCount)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                        
                        Menu {
                            Picker("Sort By", selection: $sortOrder) {
                                ForEach(StudyView.StudySortOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            Divider()
                            Picker("Filter", selection: $settings.studyFilter) {
                                Text("All").tag(StudyFilter.all)
                                Text("Unread").tag(StudyFilter.unread)
                            }
                        } label: {
                            Image(systemName: settings.studyFilter == .all && sortOrder == .recent ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            } else {
                // MARK: - macOS Desktop Header
                VStack(spacing: 0) {
                    // Row 1: Title, Stats, Actions
                    HStack(spacing: 16) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Text(selectedJournal?.name ?? "All Feeds")
                            .font(.system(.title3, design: .rounded).bold())
                        
                        // Unread count badge
                        if rssService.items.count > 0 {
                            let unreadCount = rssService.items.filter { item in
                                !readArticles.contains { $0.url == item.link }
                            }.count
                            
                            Text("\(unreadCount) unread")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(unreadCount > 0 ? .orange : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(unreadCount > 0 ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: {
                            rssService.fetchAllFeeds(feeds: Array(feeds))
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(rssService.isFetching ? 0.3 : 1)
                        .disabled(rssService.isFetching)
                        
                        Button(action: { showFeedManager = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Row 2: Toolbar Controls
                    HStack(spacing: 12) {
                        // Source Picker (inline)
                        Picker("Source", selection: $selectedJournal) {
                            Text("All Sources").tag(Optional<RSSFeed>.none)
                            Divider()
                            ForEach(feeds) { feed in
                                Text(feed.name).tag(Optional(feed))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .controlSize(.small)
                        
                        Divider().frame(height: 20)
                        
                        // Search
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                        .frame(maxWidth: 220)
                        
                        Spacer()
                        
                        // Sort
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(StudyView.StudySortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .controlSize(.small)
                        
                        // Filter Toggle
                        Picker("Filter", selection: $settings.studyFilter) {
                            Text("All").tag(StudyFilter.all)
                            Text("Unread").tag(StudyFilter.unread)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                        .controlSize(.small)
                        
                        Divider().frame(height: 20)
                        
                        // View Toggle
                        HStack(spacing: 0) {
                            Button(action: { settings.studyLayoutStyle = .grid }) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 28, height: 24)
                            }
                            .buttonStyle(.plain)
                            .background(settings.studyLayoutStyle == .grid ? Color.accentColor.opacity(0.15) : Color.clear)
                            .foregroundColor(settings.studyLayoutStyle == .grid ? .accentColor : .secondary)
                            
                            Button(action: { settings.studyLayoutStyle = .list }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 28, height: 24)
                            }
                            .buttonStyle(.plain)
                            .background(settings.studyLayoutStyle == .list ? Color.accentColor.opacity(0.15) : Color.clear)
                            .foregroundColor(settings.studyLayoutStyle == .list ? .accentColor : .secondary)
                        }
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                        
                        // Column adjuster (grid only)
                        if settings.studyLayoutStyle == .grid {
                            HStack(spacing: 2) {
                                Button(action: { if settings.studyColumns > 1 { settings.studyColumns -= 1 } }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 9, weight: .bold))
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(settings.studyColumns)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(width: 16)
                                
                                Button(action: { if settings.studyColumns < 6 { settings.studyColumns += 1 } }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                .background(settings.theme.backgroundColor)
            }
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
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var filteredItems: [RSSItem] {
        var items = rssService.items
        
        // Filter by selected source/journal
        if let journal = selectedJournal {
            items = items.filter { $0.journalName == journal.name }
        }
        
        if settings.studyFilter == .unread {
            let readUrls = Set(readArticles.map { $0.url })
            items = items.filter { !readUrls.contains($0.link) }
        }
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
                if settings.studyLayoutStyle == .grid && sizeClass != .compact {
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
    @State private var isHovering = false
    
    var isRead: Bool {
        readArticles.contains { $0.url == item.link }
    }
    
    var isStarred: Bool {
        readArticles.first(where: { $0.url == item.link })?.isFlagged ?? false
    }
    
    var body: some View {
        Button(action: {
            if let url = URL(string: item.link)?.proxied(using: settings) {
                openURL(url)
                if !isRead {
                    let newRead = ReadArticle(url: item.link, title: item.cleanTitle, category: "Article", publicationName: item.journalName)
                    modelContext.insert(newRead)
                }
            }
        }) {
            HStack(spacing: 16) {
                // Read indicator (left edge)
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRead ? Color.clear : Color.accentColor)
                    .frame(width: 3)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Metadata row
                    HStack(spacing: 8) {
                        Text(item.journalName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)
                        
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        if isStarred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Title
                    Text(item.cleanTitle)
                        .font(.system(.body, design: .serif))
                        .fontWeight(.medium)
                        .foregroundColor(settings.theme.textColor.opacity(isRead ? 0.5 : 1.0))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Quick actions (visible on hover)
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: toggleStar) {
                            Image(systemName: isStarred ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(isStarred ? .orange : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: toggleRead) {
                            Image(systemName: isRead ? "circle" : "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(isRead ? .secondary : .green)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                } else if isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green.opacity(0.6))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isHovering ? Color.primary.opacity(0.03) : settings.theme.backgroundColor)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.04)),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(action: toggleRead) {
                Label(isRead ? "Mark as Unread" : "Mark as Read", systemImage: isRead ? "circle" : "checkmark.circle")
            }
            Button(action: toggleStar) {
                Label(isStarred ? "Unstar" : "Star", systemImage: isStarred ? "star.slash" : "star")
            }
            Divider()
            Button(action: { if let url = URL(string: item.link)?.proxied(using: settings) { openURL(url) } }) {
                Label("Open in Browser", systemImage: "safari")
            }
        }
    }
    
    private func toggleRead() {
        if isRead {
            if let existing = readArticles.first(where: { $0.url == item.link }) {
                modelContext.delete(existing)
            }
        } else {
            let newRead = ReadArticle(url: item.link, title: item.cleanTitle, category: "Article", publicationName: item.journalName)
            modelContext.insert(newRead)
        }
    }
    
    private func toggleStar() {
        if let existing = readArticles.first(where: { $0.url == item.link }) {
            existing.isFlagged.toggle()
        } else {
            let newRead = ReadArticle(url: item.link, title: item.cleanTitle, category: "Article", publicationName: item.journalName)
            newRead.isFlagged = true
            modelContext.insert(newRead)
        }
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
