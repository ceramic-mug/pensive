import SwiftUI
import SwiftData

struct StudyHomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var rssService: RSSService
    @Environment(\.horizontalSizeClass) var sizeClass
    @Query(sort: \RSSFeed.name) private var feeds: [RSSFeed]
    @Query(sort: \ReadArticle.dateRead, order: .reverse) private var readArticles: [ReadArticle]
    
    var onSelectFeed: (RSSFeed?) -> Void
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
    
    @State private var showFeedManager = false
    @State private var selectedFeed: RSSFeed? = nil // nil means "All"
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            
            GeometryReader { geo in
                UnifiedModuleHeader(
                    title: "Study",
                    subtitle: Date().formatted(date: .long, time: .omitted),
                    onBack: { sidebarSelection = .home },
                    onShowSettings: { showSettings = true }
                )
                    
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: isCompact ? 24 : 32) {
                            Spacer(minLength: isCompact ? 10 : 80)
                                
                                VStack(spacing: 8) {
                                    Text("Choose a source to begin reading")
                                        .font(getFont(size: isCompact ? 13 : 16, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            
                            VStack(spacing: isCompact ? 24 : 32) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 110 : 160, maximum: isCompact ? 160 : 200), spacing: isCompact ? 12 : 18)], spacing: isCompact ? 12 : 18) {
                                    // "All" option
                                    FeedTile(
                                        title: "All Feeds",
                                        color: .accentColor,
                                        isSelected: selectedFeed == nil,
                                        isCompact: isCompact
                                    ) {
                                        selectedFeed = nil
                                        navigateToDashboard()
                                    }
                                    
                                    // User feeds
                                    ForEach(feeds) { feed in
                                        FeedTile(
                                            title: feed.name,
                                            color: .orange,
                                            isSelected: selectedFeed?.id == feed.id,
                                            isCompact: isCompact
                                        ) {
                                            selectedFeed = feed
                                            navigateToDashboard()
                                        }
                                    }
                                    
                                    // Feed Management Tile
                                    ManagementTile(isCompact: isCompact) {
                                        showFeedManager = true
                                    }
                                }
                                
                                if !readArticles.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Previously Read")
                                            .font(getFont(size: isCompact ? 18 : 22, weight: .bold))
                                            .foregroundColor(settings.theme.textColor.opacity(0.8))
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: isCompact ? 12 : 16) {
                                                ForEach(readArticles.prefix(10)) { article in
                                                    HistoryCard(article: article)
                                                        .frame(width: isCompact ? 180 : 240)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, isCompact ? 12 : 20)
                                }
                            }
                            .padding(.horizontal, isCompact ? 20 : 40)
                            .frame(maxWidth: 1000)
                            
                            Spacer(minLength: isCompact ? 20 : 40)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height - (isCompact ? 80 : 0))
                    }
                }
            }
            .sheet(isPresented: $showFeedManager) {
                FeedManagementView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settings)
            }
        }
    }
    
    
    
    private func navigateToDashboard() {
        onSelectFeed(selectedFeed)
    }

    private func getFont(size: Double, weight: Font.Weight = .regular) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

struct FeedTile: View {
    let title: String
    let color: Color
    let isSelected: Bool
    var isCompact: Bool = false
    let action: () -> Void
    @EnvironmentObject var settings: AppSettings
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 6 : 10) {
                Text(title)
                    .font(getFont(size: isCompact ? 14 : 16, weight: .bold))
                    .foregroundColor(settings.theme.textColor.opacity(isSelected ? 1.0 : 0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: isCompact ? 32 : 44)
            }
            .padding(.horizontal, isCompact ? 10 : 16)
            .padding(.vertical, isCompact ? 16 : 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 24)
                    .fill(isSelected ? color.opacity(0.15) : settings.theme.textColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 24)
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

    private func getFont(size: Double, weight: Font.Weight = .regular) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
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
                .font(getFont(size: 13, weight: .bold))
                .foregroundColor(settings.theme.textColor)
                .lineLimit(4)
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

    private func getFont(size: Double, weight: Font.Weight = .regular) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

// MARK: - Management Tile
struct ManagementTile: View {
    var isCompact: Bool
    var action: () -> Void
    @EnvironmentObject var settings: AppSettings
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 4 : 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: isCompact ? 18 : 22))
                    .foregroundColor(settings.theme.textColor.opacity(0.4))
                
                Text(isCompact ? "Add" : "Manage Sources")
                    .font(getFont(size: isCompact ? 11 : 13, weight: .bold))
                    .foregroundColor(settings.theme.textColor.opacity(0.4))
            }
            .padding(.vertical, isCompact ? 16 : 24)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 64 : 92)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 24)
                    .stroke(settings.theme.textColor.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(settings.theme.textColor.opacity(0.01))
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func getFont(size: Double, weight: Font.Weight = .regular) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
