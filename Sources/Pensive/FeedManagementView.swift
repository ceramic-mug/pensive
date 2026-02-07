import SwiftUI
import SwiftData

struct FeedManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RSSFeed.name) private var feeds: [RSSFeed]
    
    @State private var showingAddFeed = false
    @State private var newFeedName = ""
    @State private var newFeedURL = ""
    @State private var editingFeed: RSSFeed? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section("Your Feeds") {
                    ForEach(feeds) { feed in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(feed.name)
                                    .font(.headline)
                                Text(feed.urlString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { editingFeed = feed; newFeedName = feed.name; newFeedURL = feed.urlString }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete(perform: deleteFeeds)
                }
                
                Section {
                    Button(action: { showingAddFeed = true }) {
                        Label("Add New Feed", systemImage: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationTitle("Manage Feeds")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddFeed) {
                feedEditor(title: "Add Feed", action: addFeed)
            }
            .sheet(item: $editingFeed) { feed in
                feedEditor(title: "Edit Feed", action: { updateFeed(feed) })
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
    
    private func feedEditor(title: String, action: @escaping () -> Void) -> some View {
        NavigationStack {
            Form {
                TextField("Feed Name", text: $newFeedName)
                TextField("RSS URL", text: $newFeedURL)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        showingAddFeed = false
                        editingFeed = nil
                        newFeedName = ""
                        newFeedURL = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: action)
                        .disabled(newFeedName.isEmpty || newFeedURL.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 300, height: 200)
        #endif
    }
    
    private func addFeed() {
        let feed = RSSFeed(name: newFeedName, urlString: newFeedURL)
        modelContext.insert(feed)
        newFeedName = ""
        newFeedURL = ""
        showingAddFeed = false
    }
    
    private func updateFeed(_ feed: RSSFeed) {
        feed.name = newFeedName
        feed.urlString = newFeedURL
        newFeedName = ""
        newFeedURL = ""
        editingFeed = nil
    }
    
    private func deleteFeeds(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(feeds[index])
        }
    }
}
