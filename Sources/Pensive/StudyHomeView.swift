import SwiftUI
import SwiftData

struct StudyHomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var rssService: RSSService
    @Query(sort: \RSSFeed.name) private var feeds: [RSSFeed]
    @Query(sort: \ReadArticle.dateRead, order: .reverse) private var readArticles: [ReadArticle]
    
    var onSelectFeed: (RSSFeed?, StudySortOrder) -> Void
    
    @State private var showActivity = false
    @State private var showFeedManager = false
    @State private var selectedFeed: RSSFeed? = nil // nil means "All"
    @State private var sortOrder: StudySortOrder = .recent
    
    enum StudySortOrder: String, CaseIterable, Identifiable {
        case recent = "Most Recent"
        case alphabeticalTitle = "Title A-Z"
        case alphabeticalAuthor = "Author A-Z"
        case random = "Random Shuffle"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Header Area (Fixed)
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
                        VStack(spacing: 32) {
                            Spacer(minLength: 40)
                            
                            VStack(spacing: 8) {
                                Text("Study")
                                    .font(.system(size: 64, weight: .bold, design: .serif))
                                    .foregroundColor(settings.theme.textColor)
                                
                                Text("Choose a source to begin reading")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            
                            VStack(spacing: 32) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)], spacing: 20) {
                                    // "All" option
                                    FeedTile(
                                        title: "All Feeds",
                                        color: .accentColor,
                                        isSelected: selectedFeed == nil
                                    ) {
                                        selectedFeed = nil
                                        navigateToDashboard()
                                    }
                                    
                                    // User feeds
                                    ForEach(feeds) { feed in
                                        FeedTile(
                                            title: feed.name,
                                            color: .orange,
                                            isSelected: selectedFeed?.id == feed.id
                                        ) {
                                            selectedFeed = feed
                                            navigateToDashboard()
                                        }
                                    }
                                }
                                
                                if !readArticles.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Previously Read")
                                            .font(.system(.title3, design: .serif).bold())
                                            .foregroundColor(settings.theme.textColor.opacity(0.8))
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(readArticles.prefix(10)) { article in
                                                    HistoryCard(article: article)
                                                        .frame(width: 240)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 20)
                                }
                            }
                            .padding(.horizontal, 40)
                            .frame(maxWidth: 1000)
                            
                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height)
                    }
                    
                    VStack {
                        Spacer()
                        // Footer Controls
                        HStack(spacing: 32) {
                            sortMenu
                                .fixedSize()
                            
                            Divider()
                                .frame(height: 20)
                                .opacity(0.1)
                            
                            Button(action: { showFeedManager = true }) {
                                Label("Manage Feeds", systemImage: "pencil.and.outline")
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { withAnimation { showActivity = true } }) {
                                Label("Activity", systemImage: "chart.bar.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundColor(.secondary)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(settings.theme.backgroundColor)
                    }
                }
            }
            
            if showActivity {
                activityOverlay
            }
        }
        .sheet(isPresented: $showFeedManager) {
            FeedManagementView()
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
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
            
            Text("Study")
                .font(.system(size: 64, weight: .bold, design: .serif))
                .foregroundColor(settings.theme.textColor)
            
            Text("Choose a source to begin reading")
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private var sortMenu: some View {
        Menu {
            Picker("Sort Order", selection: $sortOrder) {
                ForEach(StudySortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(sortOrder.rawValue)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .opacity(0.5)
            }
        }
        .menuStyle(.borderlessButton)
    }
    
    private var activityOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
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
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func navigateToDashboard() {
        onSelectFeed(selectedFeed, sortOrder)
    }
}

struct FeedTile: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var settings: AppSettings
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(.headline, design: .serif).bold())
                    .foregroundColor(settings.theme.textColor.opacity(isSelected ? 1.0 : 0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 50)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? color.opacity(0.15) : settings.theme.textColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isSelected ? color.opacity(0.4) : settings.theme.textColor.opacity(isHovered ? 0.1 : 0), lineWidth: 2)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct HistoryCard: View {
    let article: ReadArticle
    @EnvironmentObject var settings: AppSettings
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(article.publicationName)
                .font(.caption.bold())
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
            
            Text(article.title)
                .font(.system(.subheadline, design: .serif).bold())
                .foregroundColor(settings.theme.textColor)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            HStack {
                Text(article.dateRead.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if article.isFlagged {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.theme.textColor.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(settings.theme.textColor.opacity(isHovered ? 0.1 : 0), lineWidth: 1)
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
