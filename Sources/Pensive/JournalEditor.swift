import SwiftUI
import SwiftData
import MapKit

struct EntryEditor: View {
    @Bindable var section: JournalSection
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    
    @State private var draftText: String = ""
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var isPickerPresented = false
    @State private var pickerQuery = ""
    @State private var pickerPosition: CGPoint = .zero
    @State private var selectedIndex = 0
    @State private var textHeight: CGFloat = 400
    
    var body: some View {
        NativeTextView(
            text: $draftText,
            height: $textHeight,
            fontName: fontName,
            fontSize: fontSize,
            textColor: textColor,
            selectionColor: selectionColor,
            horizontalPadding: horizontalPadding,
            isPickerPresented: $isPickerPresented,
            pickerQuery: $pickerQuery,
            pickerPosition: $pickerPosition,
            onCommand: handlePickerCommand
        )
        .frame(minHeight: textHeight)
        .overlay(alignment: .topLeading) {
            if isPickerPresented {
                SymbolPicker(query: $pickerQuery, selectedIndex: $selectedIndex) { item in
                    insertSymbol(item)
                }
                .padding(.top, 40)
                .padding(.leading, horizontalPadding + 20)
                .transition(.scale(0.9).combined(with: .opacity))
            }
        }
        .onAppear {
            draftText = section.content
        }
        .onDisappear {
            saveImmediately()
        }
        .onChange(of: draftText) { oldValue, newValue in
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        section.content = draftText
                    }
                }
            }
        }
    }
    
    private func saveImmediately() {
        saveTask?.cancel()
        section.content = draftText
    }
    
    private func handlePickerCommand(_ command: NativeTextView.ControlCommand) -> Bool {
        guard isPickerPresented else { return false }
        let filteredCount = filteredSymbolsCount()
        guard filteredCount > 0 else { return false }
        
        switch command {
        case .moveUp:
            selectedIndex = (selectedIndex - 1 + filteredCount) % filteredCount
            return true
        case .moveDown:
            selectedIndex = (selectedIndex + 1) % filteredCount
            return true
        case .confirm, .complete:
            if let item = getSelectedItem() {
                insertSymbol(item)
                return true
            }
        case .cancel:
            isPickerPresented = false
            return true
        }
        return false
    }
    
    private func filteredSymbolsCount() -> Int {
        if pickerQuery.isEmpty { return symbolMap.count }
        return symbolMap.filter { $0.name.lowercased().contains(pickerQuery.lowercased()) }.count
    }
    
    private func getSelectedItem() -> SymbolItem? {
        let filtered = pickerQuery.isEmpty ? symbolMap : symbolMap.filter { $0.name.lowercased().contains(pickerQuery.lowercased()) }
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }
    
    private func insertSymbol(_ item: SymbolItem) {
        let trigger = "/" + pickerQuery
        if let range = draftText.range(of: trigger, options: .backwards) {
            draftText.replaceSubrange(range, with: item.symbol)
            isPickerPresented = false
            pickerQuery = ""
        }
    }
}

struct ExpandingSettingsMenu: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Bindable var entry: JournalEntry
    @Binding var isExpanded: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var selectedEntryID: UUID?
    @State private var isTypographyPresented = false
    var onDeleted: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            toggleButton
            if isExpanded {
                expandedContent
            }
        }
    }

    private var toggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            Image(systemName: isExpanded ? "chevron.left" : "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .help(isExpanded ? "Collapse Settings" : "Expand Settings")
    }

    private var expandedContent: some View {
        HStack(spacing: 12) {
            Group {
                Button(action: {
                    selectedEntryID = nil
                }) {
                    Image(systemName: "house")
                        .font(.system(size: 13))
                }
                .help("Back to Journal Home")
                
                Divider().frame(height: 12)

                HStack(spacing: 8) {
                    Button(action: { settings.textSize = max(12, settings.textSize - 1) }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 12))
                    }
                    .help("Smaller Text")
                    
                    Button(action: { settings.textSize = min(72, settings.textSize + 1) }) {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 12))
                    }
                    .help("Larger Text")
                }
                
                HStack(spacing: 6) {
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: { settings.theme = theme }) {
                            Circle()
                                .fill(theme.backgroundColor)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(settings.theme.textColor.opacity(settings.theme == theme ? 0.8 : 0.2), lineWidth: 1)
                                )
                                .scaleEffect(settings.theme == theme ? 1.2 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .help(theme.rawValue.capitalized)
                    }
                }
            }
            .foregroundColor(settings.theme.textColor.opacity(0.7))

            typographyMenu
            dangerousActionsMenu
        }
        .padding(.leading, 8)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var typographyMenu: some View {
        Button(action: { isTypographyPresented.toggle() }) {
            Image(systemName: "textformat")
                .font(.system(size: 13))
                .foregroundColor(settings.theme.textColor.opacity(0.7))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isTypographyPresented, arrowEdge: .top) {
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
        .help("Font & Margins")
    }

    private var dangerousActionsMenu: some View {
        Menu {
            Button(role: .destructive, action: { 
                modelContext.delete(entry)
                isExpanded = false
                onDeleted()
            }) {
                Label("Delete Entry", systemImage: "trash")
            }
            
            Button(action: {
                let locationManager = LocationManager()
                locationManager.requestLocation()
            }) {
                Label("Update Location", systemImage: "location")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13))
                .foregroundColor(settings.theme.textColor.opacity(0.7))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("More Actions")
    }
}

struct ToolbarIconButton: View {
    let icon: String
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}
