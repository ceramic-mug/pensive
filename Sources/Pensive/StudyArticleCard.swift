import SwiftUI
import SwiftData

struct StudyArticleCard: View {
    @Environment(\.modelContext) private var modelContext
    let item: RSSItem
    let journalName: String
    let category: String
    @Query private var readArticles: [ReadArticle]
    
    @State private var fetchedSections: [AbstractSection]? = nil
    @State private var isFetchingAbstract = false
    @State private var fetchError: String? = nil
    @State private var isExpanded = false
    
    var isRead: Bool {
        readArticles.contains { $0.url == item.link }
    }
    
    var isStarred: Bool {
        readArticles.first(where: { $0.url == item.link })?.isFlagged ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header Image
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 160)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // MARK: - Metadata
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.cleanTitle)
                            .font(.system(.title3, design: .serif).weight(.medium))
                            .foregroundColor(isRead ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                        
                        HStack(spacing: 6) {
                            if !journalName.isEmpty {
                                Text(journalName)
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .cornerRadius(4)
                            }
                            
                            Text(item.pubDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Abstract Content
                // Priority: Fetched > Parsed > Description
                let displaySections = fetchedSections ?? item.abstractSections
                
                if let sections = displaySections, !sections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sections.prefix(isExpanded ? 10 : 2)) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Text(section.content)
                                    .font(.callout)
                                    .foregroundColor(.primary.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(isExpanded ? nil : 6)
                            }
                        }
                        
                        if sections.count > 2 && !isExpanded {
                            Button(action: { withAnimation { isExpanded = true } }) {
                                Text("Read more...")
                                    .font(.caption.bold())
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    // Fallback Description
                    if !item.cleanDescription.isEmpty {
                        Text(item.cleanDescription)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // MARK: - Auto-Fetch / Loading State
                if fetchedSections == nil && item.abstractSections == nil && item.doi != nil {
                    if isFetchingAbstract {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Loading abstract...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        .transition(.opacity)
                    } else if fetchError != nil {
                         // Only show retry button on error, don't auto-retry endlessly
                        Button("Retry Abstract") { fetchAbstract() }
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                         // Invisible trigger for auto-fetch
                         Color.clear
                            .frame(height: 1)
                            .onAppear {
                                print("DEBUG: StudyArticleCard onAppear triggered for \(item.title.prefix(20))")
                                fetchAbstract()
                            }
                    }
                }
                
                // MARK: - Action Bar
                Divider()
                    .padding(.top, 4)
                
                HStack {
                    Button(action: {
                        if let url = URL(string: item.link) {
                            NSWorkspace.shared.open(url)
                            markAsRead()
                        }
                    }) {
                        Label("Read", systemImage: "safari")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: toggleRead) {
                        Image(systemName: isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(isRead ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isRead ? "Mark as Unread" : "Mark as Read")
                    
                    Button(action: toggleStar) {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundColor(isStarred ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isStarred ? "Unstar" : "Star")
                }
            }
            .padding(16)
        }
        .background(Color(.windowBackgroundColor)) // Card background
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func fetchAbstract() {
        guard let doi = item.doi else { return }
        // Prevent duplicate fetches if already have sections or currently fetching
        if isFetchingAbstract || fetchedSections != nil { return }
        
        isFetchingAbstract = true
        fetchError = nil
        
        Task {
            do {
                let abstractText = try await PubMedService.shared.fetchAbstract(doi: doi)
                
                await MainActor.run {
                    withAnimation {
                        // Try to parse it into sections
                        if let parsed = RSSItem.parseAbstractSections(from: abstractText) {
                            self.fetchedSections = parsed
                        } else {
                            // If no sections found, just return whole text as one section
                            self.fetchedSections = [AbstractSection(title: "Abstract", content: abstractText)]
                        }
                        self.isFetchingAbstract = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.fetchError = error.localizedDescription
                    self.isFetchingAbstract = false
                }
            }
        }
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
