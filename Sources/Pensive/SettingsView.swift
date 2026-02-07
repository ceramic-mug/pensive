import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                scriptureSection
                dataMigrationSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 650)
        #endif
    }

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }
            .onChange(of: settings.theme) { oldValue, newValue in
                UbiquitousStore.shared.set(newValue.rawValue, forKey: "theme")
            }
            
            Picker("Font", selection: $settings.font) {
                ForEach(AppFont.allCases) { font in
                    Text(font.rawValue.capitalized).tag(font)
                }
            }
            .onChange(of: settings.font) { oldValue, newValue in
                UbiquitousStore.shared.set(newValue.rawValue, forKey: "font")
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Text Size")
                    Spacer()
                    Text("\(Int(settings.textSize))pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.textSize, in: 12...48, step: 1)
                    .onChange(of: settings.textSize) { oldValue, newValue in
                        UbiquitousStore.shared.set(newValue, forKey: "textSize")
                    }
            }
        }
    }

    private var scriptureSection: some View {
        Section(header: Text("Scripture")) {
            SecureField("ESV API Key", text: $settings.esvApiKey)
                .onChange(of: settings.esvApiKey) { oldValue, newValue in
                    UbiquitousStore.shared.set(newValue, forKey: "esvApiKey")
                }
        }
    }

    private var dataMigrationSection: some View {
        Section(header: Text("Data & Migration")) {
            NavigationLink(destination: JournalExportView()) {
                Label("Export Journal", systemImage: "square.and.arrow.up")
            }
            
            #if os(macOS)
            DataImportView(context: modelContext)
            #endif
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Export Logic

struct ExportableJournal: Codable {
    let entries: [ExportableEntry]
}

struct ExportableEntry: Codable {
    let id: UUID
    let date: Date
    let content: String
    let isFavorite: Bool
    let tags: [String]
    let sections: [ExportableSection]
}

struct ExportableSection: Codable {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
}

struct JournalExportView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var showingExportPicker = false
    @State private var exportDocument: JournalJSONDocument?
    @State private var exportStatus: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Export Journal")
                .font(.title.bold())
            
            Text("This will create a JSON backup of all your journal entries and sections. You can save this file to your Desktop for safe keeping.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if !exportStatus.isEmpty {
                Text(exportStatus)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Button(action: prepareExport) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Export All Entries (\(entries.count))")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.top)
        }
        .padding(30)
        .frame(width: 400)
        .fileExporter(
            isPresented: $showingExportPicker,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Pensive_Journal_Backup"
        ) { result in
            switch result {
            case .success(let url):
                exportStatus = "Successfully exported to \(url.lastPathComponent)"
            case .failure(let error):
                exportStatus = "Export failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func prepareExport() {
        let exportableEntries = entries.map { entry in
            ExportableEntry(
                id: entry.id,
                date: entry.date,
                content: entry.content,
                isFavorite: entry.isFavorite,
                tags: entry.tags,
                sections: entry.sections?.map { section in
                    ExportableSection(
                        id: section.id,
                        title: section.title,
                        content: section.content,
                        timestamp: section.timestamp
                    )
                } ?? []
            )
        }
        
        let backup = ExportableJournal(entries: exportableEntries)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)
            exportDocument = JournalJSONDocument(data: data)
            showingExportPicker = true
        } catch {
            exportStatus = "Failed to prepare export: \(error.localizedDescription)"
        }
    }
}

struct JournalJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Import Logic

#if os(macOS)
@MainActor
class DataMigrationService: ObservableObject {
    @Published var isMigrating = false
    @Published var progressMessage = ""
    @Published var error: String?
    
    private let mainContext: ModelContext
    
    init(mainContext: ModelContext) {
        self.mainContext = mainContext
    }
    
    func migrateFromLegacyBackup(at url: URL, settingsUrl: URL?) async {
        isMigrating = true
        error = nil
        progressMessage = "Preparing migration..."
        
        do {
            // 1. Migrate Settings if available
            if let settingsUrl = settingsUrl {
                progressMessage = "Restoring Settings..."
                migrateSettingsFromPlist(at: settingsUrl)
            }

            let schema = Schema([
                JournalEntry.self,
                JournalSection.self,
                ReadArticle.self,
                ReadDay.self
            ])
            
            // 2. Create a lightweight container for the legacy store
            let config = ModelConfiguration(url: url)
            let legacyContainer = try ModelContainer(for: schema, configurations: config)
            let legacyContext = ModelContext(legacyContainer)
            
            // 3. Migrate Journal Entries
            progressMessage = "Migrating Journal Entries..."
            try await migrateJournalEntries(from: legacyContext)
            
            // 4. Migrate Read Articles
            progressMessage = "Migrating Study Progress..."
            try await migrateReadArticles(from: legacyContext)
            
            // 5. Migrate Read Days
            progressMessage = "Migrating Scripture Progress..."
            try await migrateReadDays(from: legacyContext)
            
            progressMessage = "Migration Successful!"
            try mainContext.save()
        } catch {
            self.error = "Migration failed: \(error.localizedDescription)"
            print("MIGRATION ERROR: \(error)")
        }
        
        isMigrating = false
    }

    private func migrateSettingsFromPlist(at url: URL) {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return
        }

        let keysToMigrate = ["theme", "font", "textSize", "editorWidth", "marginPercentage", "esvApiKey"]
        for key in keysToMigrate {
            if let value = plist[key] {
                UbiquitousStore.shared.set(value, forKey: key)
            }
        }
    }
    
    private func migrateJournalEntries(from legacyContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<JournalEntry>()
        let legacyEntries = try legacyContext.fetch(descriptor)
        
        for legacyEntry in legacyEntries {
            let id = legacyEntry.id
            let mainDescriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
            let existing = try mainContext.fetch(mainDescriptor)
            
            if existing.isEmpty {
                let newEntry = JournalEntry(content: legacyEntry.content, date: legacyEntry.date)
                newEntry.id = legacyEntry.id
                newEntry.latitude = legacyEntry.latitude
                newEntry.longitude = legacyEntry.longitude
                newEntry.locationName = legacyEntry.locationName
                newEntry.isFavorite = legacyEntry.isFavorite
                newEntry.tags = legacyEntry.tags
                
                mainContext.insert(newEntry)
                
                if let sections = legacyEntry.sections {
                    for legacySection in sections {
                        let newSection = JournalSection(
                            content: legacySection.content,
                            title: legacySection.title,
                            timestamp: legacySection.timestamp
                        )
                        newSection.id = legacySection.id
                        newSection.entry = newEntry
                        mainContext.insert(newSection)
                    }
                }
            } else if let existingEntry = existing.first {
                // If it exists, ensure we have the sections
                if (existingEntry.sections ?? []).isEmpty, let legacySections = legacyEntry.sections, !legacySections.isEmpty {
                    for legacySection in legacySections {
                        let newSection = JournalSection(
                            content: legacySection.content,
                            title: legacySection.title,
                            timestamp: legacySection.timestamp
                        )
                        newSection.id = legacySection.id
                        newSection.entry = existingEntry
                        mainContext.insert(newSection)
                    }
                }
            }
        }
    }
    
    private func migrateReadArticles(from legacyContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<ReadArticle>()
        let legacyArticles = try legacyContext.fetch(descriptor)
        
        for legacyArticle in legacyArticles {
            let url = legacyArticle.url
            let mainDescriptor = FetchDescriptor<ReadArticle>(predicate: #Predicate { $0.url == url })
            let existing = try mainContext.fetch(mainDescriptor)
            
            if existing.isEmpty {
                let newArticle = ReadArticle(
                    url: legacyArticle.url,
                    title: legacyArticle.title,
                    category: legacyArticle.category,
                    publicationName: legacyArticle.publicationName
                )
                newArticle.dateRead = legacyArticle.dateRead
                newArticle.isFlagged = legacyArticle.isFlagged
                mainContext.insert(newArticle)
            }
        }
    }
    
    private func migrateReadDays(from legacyContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<ReadDay>()
        let legacyDays = try legacyContext.fetch(descriptor)
        
        for legacyDay in legacyDays {
            let dateString = legacyDay.dateString
            let mainDescriptor = FetchDescriptor<ReadDay>(predicate: #Predicate { $0.dateString == dateString })
            let existing = try mainContext.fetch(mainDescriptor)
            
            if existing.isEmpty {
                let newDay = ReadDay(dateString: legacyDay.dateString, isRead: legacyDay.isRead)
                mainContext.insert(newDay)
            }
        }
    }
}

struct DataImportView: View {
    @StateObject private var migrationService: DataMigrationService
    @State private var showingImportAlert = false
    
    init(context: ModelContext) {
        _migrationService = StateObject(wrappedValue: DataMigrationService(mainContext: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { showingImportAlert = true }) {
                Label("Import Legacy Desktop Backup", systemImage: "tray.and.arrow.down")
            }
            .disabled(migrationService.isMigrating)
            
            if migrationService.isMigrating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(migrationService.progressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = migrationService.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if !migrationService.progressMessage.isEmpty {
                Text(migrationService.progressMessage)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .alert("Import Legacy Data?", isPresented: $showingImportAlert) {
            Button("Import", role: .none) {
                startMigration()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will look for 'journal.store' in your Desktop backup folder and merge your legacy journal and scripture progress into iCloud. This will NOT delete any existing data.")
        }
    }
    
    private func startMigration() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let backupURL = homeDir.appendingPathComponent("Desktop/Pensive_Manual_Backup/journal.store")
        let settingsURL = homeDir.appendingPathComponent("Desktop/Pensive_Manual_Backup/com.joshua.pensive.plist")
        
        if FileManager.default.fileExists(atPath: backupURL.path) {
            Task {
                await migrationService.migrateFromLegacyBackup(
                    at: backupURL, 
                    settingsUrl: FileManager.default.fileExists(atPath: settingsURL.path) ? settingsURL : nil
                )
            }
        } else {
            migrationService.error = "Backup file not found at ~/Desktop/Pensive_Manual_Backup/journal.store"
        }
    }
}
#endif
