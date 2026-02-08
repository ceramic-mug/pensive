import SwiftUI
import SwiftData

struct StudyArticleCard: View {
    @Environment(\.modelContext) private var modelContext
    let item: RSSItem
    let journalName: String
    let category: String
    @Query private var readArticles: [ReadArticle]
    
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var isHovering = false
    @State private var isTapped = false
    
    var isRead: Bool {
        readArticles.contains { $0.url == item.link }
    }
    
    var isStarred: Bool {
        readArticles.first(where: { $0.url == item.link })?.isFlagged ?? false
    }
    
    private var cardBackground: Color {
        if isRead {
            return settings.theme.textColor.opacity(0.01)
        }
        return settings.theme.textColor.opacity(0.03)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Image (Optional)
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: settings.studyColumns > 4 ? 60 : 100)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: settings.studyColumns > 4 ? 60 : 100)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Metadata Row
                HStack(spacing: 6) {
                    Text(journalName.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.accentColor)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isStarred {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 8))
                    }
                    
                    if isRead {
                        Button(action: toggleRead) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green.opacity(0.8))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Title
                Text(item.cleanTitle)
                    .font(.system(size: settings.studyColumns > 3 ? 13 : 15, weight: .medium, design: .serif))
                    .foregroundColor(settings.theme.textColor.opacity(isRead ? 0.4 : 0.9))
                    .lineLimit(settings.studyColumns > 4 ? 2 : 3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(settings.studyColumns > 4 ? 10 : 14)
        }
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovering ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.1 : 0), radius: 10, x: 0, y: 4)
        .scaleEffect(isTapped ? 0.97 : (isHovering ? 1.015 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHovering)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTapped)
        .onHover { hovering in
            #if os(macOS)
            isHovering = hovering
            #endif
        }
        .onTapGesture {
            handleTap()
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
    
    private func handleTap() {
        isTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            isTapped = false
            if let url = URL(string: item.link)?.proxied(using: settings) {
                openURL(url)
                markAsRead()
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
