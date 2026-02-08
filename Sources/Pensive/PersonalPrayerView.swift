import SwiftUI
import SwiftData

struct PersonalPrayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrayerArea.order) private var areas: [PrayerArea]
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var isAddingArea = false
    @State private var newAreaTitle = ""
    @FocusState private var isNewAreaFocused: Bool
    @State private var isEditing = false
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
    
    private func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if settings.font == .sans {
            return .system(size: size, weight: weight, design: .rounded)
        } else {
            return .custom(settings.font.name, size: size).weight(weight)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            settings.theme.backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 30) {
                    if isCompact {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Personal Prayer")
                                    .font(appFont(size: 32, weight: .bold))
                                    .foregroundColor(settings.theme.textColor)
                                
                                Spacer()
                                
                                Button(isEditing ? "Done" : "Edit") {
                                    withAnimation(.spring(response: 0.3)) {
                                        isEditing.toggle()
                                    }
                                }
                                .font(appFont(size: 15, weight: .semibold))
                                .foregroundColor(.accentColor)
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isAddingArea = true
                                    isNewAreaFocused = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                    Text("Add Area")
                                        .font(appFont(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(isAddingArea)
                            .opacity(isAddingArea ? 0.5 : 1.0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    } else {
                        // macOS/iPad Header - original layout
                        ZStack(alignment: .center) {
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                                        .padding(10)
                                        .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button(isEditing ? "Done" : "Edit") {
                                    withAnimation(.spring(response: 0.3)) {
                                        isEditing.toggle()
                                    }
                                }
                                .font(appFont(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(20)
                                .buttonStyle(.plain)
                                
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isAddingArea = true
                                        isNewAreaFocused = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Area")
                                    }
                                    .font(appFont(size: 14, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                                .disabled(isAddingArea)
                                .opacity(isAddingArea ? 0.5 : 1.0)
                            }
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Personal Prayer")
                                    .font(appFont(size: 34, weight: .bold))
                                    .foregroundColor(settings.theme.textColor)
                                
                                Text("Rejoice always, pray without ceasing, give thanks in all circumstances; for this is the will of God in Christ Jesus for you.")
                                    .font(settings.font == .serif ? .custom(settings.font.name, size: 16).italic() : .system(size: 16, design: .serif).italic())
                                    .foregroundColor(settings.theme.textColor.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 40)
                    }
                    
                    // iOS Compact: Single column list (Reminders-like)
                    // macOS/iPad: 3-column grid
                    if isCompact {
                        VStack(spacing: 12) {
                            if isAddingArea {
                                iOSAddAreaCard
                            }
                            
                            ForEach(areas) { area in
                                PrayerAreaCard(area: area, isCompact: true, isEditing: isEditing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ], spacing: 20) {
                            if isAddingArea {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(alignment: .top) {
                                        TextField("Area Name...", text: $newAreaTitle)
                                            .font(appFont(size: 16, weight: .semibold))
                                            .textFieldStyle(.plain)
                                            .focused($isNewAreaFocused)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                createArea()
                                            }
                                        
                                        Spacer()
                                        
                                        Button {
                                            withAnimation {
                                                isAddingArea = false
                                                newAreaTitle = ""
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(settings.theme.textColor.opacity(0.2))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(Color.accentColor.opacity(0.05))
                                    
                                    VStack {
                                        Text("Press Enter to create")
                                            .font(appFont(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(settings.theme.textColor.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                                        )
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        
                            ForEach(areas) { area in
                                PrayerAreaCard(area: area, isCompact: false, isEditing: isEditing)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 60)
                    }
                    
                    if areas.isEmpty && !isAddingArea {
                        VStack(spacing: 24) {
                            Spacer(minLength: 50)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.accentColor.opacity(0.2))
                            
                            Text("No Prayer Areas Yet")
                                .font(appFont(size: 20, weight: .bold))
                            
                            Text("Create areas like Home, Church, or World to organize your prayers.")
                                .font(appFont(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
        }
        .navigationTitle("")
        .onAppear {
            markAsPrayed()
        }
    }
    
    // MARK: - iOS Add Area Card
    private var iOSAddAreaCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Area Name...", text: $newAreaTitle)
                    .font(appFont(size: 17, weight: .medium))
                    .textFieldStyle(.plain)
                    .focused($isNewAreaFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        createArea()
                    }
                
                Spacer()
                
                if !newAreaTitle.isEmpty {
                    Button {
                        createArea()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    withAnimation {
                        isAddingArea = false
                        newAreaTitle = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(settings.theme.textColor.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(settings.theme.textColor.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    private func markAsPrayed() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        // Use environment context if possible, but for simplicity in this implementation:
        if let existing = try? modelContext.fetch(FetchDescriptor<PrayedDay>(predicate: #Predicate<PrayedDay> { $0.dateString == dateString })).first {
            existing.isPrayed = true
        } else {
            modelContext.insert(PrayedDay(dateString: dateString))
        }
        try? modelContext.save()
    }
    
    private func createArea() {
        guard !newAreaTitle.isEmpty else {
            isAddingArea = false
            return
        }
        
        let area = PrayerArea(title: newAreaTitle, order: (areas.map(\.order).max() ?? 0) + 1)
        modelContext.insert(area)
        newAreaTitle = ""
        isAddingArea = false
    }
}

struct PrayerAreaCard: View {
    @Bindable var area: PrayerArea
    var isCompact: Bool = false
    var isEditing: Bool = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @State private var newItemContent = ""
    @State private var isAddingItem = false
    @State private var isExpanded = true
    @FocusState private var isFieldFocused: Bool
    @FocusState private var editingItemID: UUID?
    @FocusState private var isTitleFocused: Bool
    
    private func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if settings.font == .sans {
            return .system(size: size, weight: weight, design: .rounded)
        } else {
            return .custom(settings.font.name, size: size).weight(weight)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card Header
            HStack(spacing: 12) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(settings.theme.textColor.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 20, height: 20)
                
                if isEditing {
                    TextField("Area Title", text: $area.title)
                        .font(appFont(size: 16, weight: .bold))
                        .foregroundColor(settings.theme.textColor)
                        .textFieldStyle(.plain)
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTitleFocused = false
                        }
                } else {
                    Text(area.title)
                        .font(appFont(size: 16, weight: .bold))
                        .foregroundColor(settings.theme.textColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isEditing {
                    Menu {
                        Button(role: .destructive) {
                            modelContext.delete(area)
                        } label: {
                            Label("Delete Area", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(settings.theme.textColor.opacity(0.3))
                            .padding(4)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .padding(.top, 2)
                    .onTapGesture {} // Prevent toggling when clicking the menu
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(settings.theme.textColor.opacity(0.03))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            
            Divider()
                .opacity(0.5)
            
            // Items List
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(area.activeItems) { item in
                        EditablePrayerItemRow(item: item, editingItemID: $editingItemID)
                    }
                    
                    // Add Item Logic - only show if isEditing
                    if isEditing {
                        if isAddingItem {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.accentColor)
                                
                                TextField("Something to pray for...", text: $newItemContent)
                                    .textFieldStyle(.plain)
                                    .font(appFont(size: 14))
                                    .focused($isFieldFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        addItem(continueAdding: true)
                                    }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.accentColor.opacity(0.05))
                        } else {
                            Button {
                                withAnimation {
                                    isAddingItem = true
                                    isFieldFocused = true
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Add Item")
                                        .font(appFont(size: 13, weight: .bold))
                                }
                                .foregroundColor(.accentColor)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(settings.theme.textColor.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(settings.theme.textColor.opacity(0.05), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        #if os(macOS)
        .onExitCommand {
            isAddingItem = false
            newItemContent = ""
            editingItemID = nil
            isTitleFocused = false
        }
        #endif
    }
    
    private func addItem(continueAdding: Bool) {
        guard !newItemContent.isEmpty else {
            isAddingItem = false
            return
        }
        
        let item = PrayerItem(content: newItemContent)
        item.area = area
        modelContext.insert(item)
        area.items?.append(item)
        newItemContent = ""
        
        if continueAdding {
            isFieldFocused = true
        } else {
            isAddingItem = false
        }
    }
}

struct EditablePrayerItemRow: View {
    @Bindable var item: PrayerItem
    @FocusState.Binding var editingItemID: UUID?
    @EnvironmentObject var settings: AppSettings
    
    private func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if settings.font == .sans {
            return .system(size: size, weight: weight, design: .rounded)
        } else {
            return .custom(settings.font.name, size: size).weight(weight)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    item.archive()
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor.opacity(0.5))
            }
            .buttonStyle(.plain)
            
            TextField("", text: $item.content)
                .font(appFont(size: 14))
                .foregroundColor(settings.theme.textColor.opacity(0.8))
                .textFieldStyle(.plain)
                .focused($editingItemID, equals: item.id)
                .submitLabel(.done)
                .onSubmit {
                    editingItemID = nil
                }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(editingItemID == item.id ? Color.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}
