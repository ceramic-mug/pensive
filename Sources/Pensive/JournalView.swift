import SwiftUI
import SwiftData

struct JournalView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    let entries: [JournalEntry]
    @Binding var selectedEntryID: UUID?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let addNewEntry: () -> Void
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let entryID = selectedEntryID, let entry = entries.first(where: { $0.id == entryID }) {
                DetailView(
                    entry: entry, 
                    columnVisibility: $columnVisibility,
                    selectedEntryID: $selectedEntryID
                )
            } else {
                JournalHomeView(
                    sidebarSelection: $sidebarSelection,
                    addNewEntry: addNewEntry,
                    selectEntry: { entry in
                        selectedEntryID = entry.id
                    }
                )
                .environmentObject(settings)
            }
        }
        .navigationTitle("")
    }
}

struct DetailView: View {
    @Bindable var entry: JournalEntry
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var selectedEntryID: UUID?
    @State private var isMenuExpanded = false
    
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
                        .padding(.bottom, 10)
                    Spacer()
                }
                
                GeometryReader { geometry in
                    VStack {
                        let calculatedPadding = geometry.size.width * settings.marginPercentage
                        
                        if let firstSection = entry.sections?.first {
                            #if os(iOS)
                            IOSJournalEditor(
                                section: firstSection,
                                fontName: settings.font.name,
                                fontSize: settings.textSize,
                                textColor: settings.theme.textColor,
                                selectionColor: settings.theme.selectionColor,
                                horizontalPadding: calculatedPadding
                            )
                            .id(firstSection.id)
                            .frame(maxWidth: geometry.size.width)
                            #else
                            ScrollView {
                                EntryEditor(
                                    section: firstSection,
                                    fontName: settings.font.name,
                                    fontSize: settings.textSize,
                                    textColor: settings.theme.textColor,
                                    selectionColor: settings.theme.selectionColor,
                                    horizontalPadding: calculatedPadding
                                )
                                .id(firstSection.id)
                                .frame(maxWidth: geometry.size.width)
                                .padding(.top, 20)
                            }
                            #endif
                        }
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .onAppear {
            if (entry.sections ?? []).isEmpty {
                let firstSection = JournalSection(content: entry.content)
                firstSection.entry = entry
                modelContext.insert(firstSection)
                entry.content = ""
            }
        }
        .toolbar {
            #if os(macOS)
            let placement = ToolbarItemPlacement.navigation
            #else
            let placement = ToolbarItemPlacement.topBarTrailing
            #endif
            ToolbarItem(placement: placement) {
                ExpandingSettingsMenu(
                    entry: entry,
                    isExpanded: $isMenuExpanded,
                    columnVisibility: $columnVisibility,
                    selectedEntryID: $selectedEntryID
                ) {
                    selectedEntryID = nil
                }
            }
        }
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }
    
    private var headerFont: Font {
        switch settings.font {
        case .sans: return .system(.headline, design: .rounded)
        case .serif: return .system(.headline, design: .serif)
        case .mono: return .system(.headline, design: .monospaced)
        }
    }
}
