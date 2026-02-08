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
                institutionalProxySection
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

    private var institutionalProxySection: some View {
        Section(header: Text("Institutional Proxy")) {
            Toggle("Enable Proxy", isOn: $settings.useInstitutionalProxy)
                .onChange(of: settings.useInstitutionalProxy) { _, newValue in
                    UbiquitousStore.shared.set(newValue, forKey: "useInstitutionalProxy")
                }
            
            if settings.useInstitutionalProxy {
                Picker("Proxy Type", selection: $settings.proxyType) {
                    ForEach(ProxyType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .onChange(of: settings.proxyType) { _, newValue in
                    UbiquitousStore.shared.set(newValue.rawValue, forKey: "proxyType")
                }
                
                TextField(settings.proxyType == .domainReplacement ? "Proxy Root (e.g. marshall.idm.oclc.org)" : "URL Prefix (e.g. https://proxy.edu/login?url=)", text: $settings.proxyRoot)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.proxyRoot) { _, newValue in
                        UbiquitousStore.shared.set(newValue, forKey: "proxyRoot")
                    }
                
                Text(settings.proxyType == .domainReplacement ? "Example: nejm.org -> www-nejm-org.\(settings.proxyRoot.isEmpty ? "proxy.edu" : settings.proxyRoot)" : "Articles will be opened via the prefix.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
import SQLite3

@MainActor
class DataMigrationService: ObservableObject {
    @Published var isMigrating = false
    @Published var progressMessage = ""
    @Published var error: String?
    
    private let mainContext: ModelContext
    
    init(mainContext: ModelContext) {
        self.mainContext = mainContext
    }
    
    func migrateFromLegacyBackup(at url: URL, folderURL: URL, settingsUrl: URL?) async {
        isMigrating = true
        error = nil
        progressMessage = "Preparing migration..."
        
        // Start accessing security-scoped resource for folder access
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // 1. Migrate Settings if available
            if let settingsUrl = settingsUrl {
                progressMessage = "Restoring Settings..."
                migrateSettingsFromPlist(at: settingsUrl)
            }

            // 2. Open SQLite database directly (we have folder permission now)
            var db: OpaquePointer?
            let openResult = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil)
            guard openResult == SQLITE_OK else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "Migration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open legacy database: \(errorMsg)"])
            }
            defer { sqlite3_close(db) }
            
            // 3. Migrate Journal Entries
            progressMessage = "Migrating Journal Entries..."
            try await migrateJournalEntriesFromSQL(db: db!)
            
            // 4. Migrate Journal Sections
            progressMessage = "Migrating Journal Sections..."
            try await migrateJournalSectionsFromSQL(db: db!)
            
            // 5. Migrate Read Articles
            progressMessage = "Migrating Study Progress..."
            try await migrateReadArticlesFromSQL(db: db!)
            
            // 6. Migrate Read Days
            progressMessage = "Migrating Scripture Progress..."
            try await migrateReadDaysFromSQL(db: db!)
            
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
    
    // Core Data reference date is Jan 1, 2001
    private func coreDataDateToDate(_ timestamp: Double) -> Date {
        let coreDataReferenceDate = Date(timeIntervalSinceReferenceDate: 0)
        return coreDataReferenceDate.addingTimeInterval(timestamp)
    }
    
    private func blobToUUID(_ blob: Data?) -> UUID {
        guard let blob = blob, blob.count >= 16 else { return UUID() }
        return blob.withUnsafeBytes { ptr -> UUID in
            guard let bytes = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return UUID() }
            return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                               bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        }
    }
    
    private func migrateJournalEntriesFromSQL(db: OpaquePointer) async throws {
        let query = "SELECT Z_PK, ZID, ZDATE, ZCONTENT, ZISFAVORITE, ZLATITUDE, ZLONGITUDE, ZLOCATIONNAME FROM ZJOURNALENTRY"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "Migration", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare journal query: \(errorMsg)"])
        }
        defer { sqlite3_finalize(statement) }
        
        var entryCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let pk = sqlite3_column_int(statement, 0)
            
            // Get UUID from blob
            var entryId = UUID()
            if let idBlob = sqlite3_column_blob(statement, 1) {
                let idLen = sqlite3_column_bytes(statement, 1)
                let idData = Data(bytes: idBlob, count: Int(idLen))
                entryId = blobToUUID(idData)
            }
            
            let dateTimestamp = sqlite3_column_double(statement, 2)
            let date = coreDataDateToDate(dateTimestamp)
            
            let content = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
            let isFavorite = sqlite3_column_int(statement, 4) != 0
            
            let latitude: Double? = sqlite3_column_type(statement, 5) != SQLITE_NULL ? sqlite3_column_double(statement, 5) : nil
            let longitude: Double? = sqlite3_column_type(statement, 6) != SQLITE_NULL ? sqlite3_column_double(statement, 6) : nil
            let locationName = sqlite3_column_text(statement, 7).map { String(cString: $0) }
            
            // Check if entry already exists
            let existingDescriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == entryId })
            let existing = try mainContext.fetch(existingDescriptor)
            
            if existing.isEmpty {
                let newEntry = JournalEntry(content: content, date: date)
                newEntry.id = entryId
                newEntry.isFavorite = isFavorite
                newEntry.latitude = latitude
                newEntry.longitude = longitude
                newEntry.locationName = locationName
                newEntry.tagsStorage = "" // Tags are rarely used, defaulting to empty
                
                mainContext.insert(newEntry)
                entryCount += 1
            }
        }
        
        print("Migrated \(entryCount) journal entries")
    }
    
    private func migrateJournalSectionsFromSQL(db: OpaquePointer) async throws {
        // First, get a mapping of legacy PKs to our entries
        let entryQuery = "SELECT Z_PK, ZID FROM ZJOURNALENTRY"
        var entryStmt: OpaquePointer?
        var pkToId: [Int32: UUID] = [:]
        
        if sqlite3_prepare_v2(db, entryQuery, -1, &entryStmt, nil) == SQLITE_OK {
            while sqlite3_step(entryStmt) == SQLITE_ROW {
                let pk = sqlite3_column_int(entryStmt, 0)
                if let idBlob = sqlite3_column_blob(entryStmt, 1) {
                    let idLen = sqlite3_column_bytes(entryStmt, 1)
                    let idData = Data(bytes: idBlob, count: Int(idLen))
                    pkToId[pk] = blobToUUID(idData)
                }
            }
            sqlite3_finalize(entryStmt)
        }
        
        let query = "SELECT ZID, ZENTRY, ZTIMESTAMP, ZCONTENT, ZTITLE FROM ZJOURNALSECTION"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "Migration", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare section query"])
        }
        defer { sqlite3_finalize(statement) }
        
        var sectionCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            var sectionId = UUID()
            if let idBlob = sqlite3_column_blob(statement, 0) {
                let idLen = sqlite3_column_bytes(statement, 0)
                let idData = Data(bytes: idBlob, count: Int(idLen))
                sectionId = blobToUUID(idData)
            }
            
            let entryPk = sqlite3_column_int(statement, 1)
            let timestamp = coreDataDateToDate(sqlite3_column_double(statement, 2))
            let content = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
            let title = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
            
            // Find the parent entry
            guard let entryId = pkToId[entryPk] else { continue }
            let entryDescriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == entryId })
            guard let parentEntry = try mainContext.fetch(entryDescriptor).first else { continue }
            
            // Check if section exists
            let existingDescriptor = FetchDescriptor<JournalSection>(predicate: #Predicate { $0.id == sectionId })
            let existing = try mainContext.fetch(existingDescriptor)
            
            if existing.isEmpty {
                let newSection = JournalSection(content: content, title: title, timestamp: timestamp)
                newSection.id = sectionId
                newSection.entry = parentEntry
                mainContext.insert(newSection)
                sectionCount += 1
            }
        }
        
        print("Migrated \(sectionCount) journal sections")
    }
    
    private func migrateReadArticlesFromSQL(db: OpaquePointer) async throws {
        let query = "SELECT ZID, ZURL, ZTITLE, ZCATEGORY, ZPUBLICATIONNAME, ZDATEREAD, ZISFLAGGED FROM ZREADARTICLE"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let url = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            let title = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
            let category = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
            let pubName = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
            let dateRead = coreDataDateToDate(sqlite3_column_double(statement, 5))
            let isFlagged = sqlite3_column_int(statement, 6) != 0
            
            let existingDescriptor = FetchDescriptor<ReadArticle>(predicate: #Predicate { $0.url == url })
            let existing = try mainContext.fetch(existingDescriptor)
            
            if existing.isEmpty {
                let newArticle = ReadArticle(url: url, title: title, category: category, publicationName: pubName)
                newArticle.dateRead = dateRead
                newArticle.isFlagged = isFlagged
                mainContext.insert(newArticle)
                count += 1
            }
        }
        
        print("Migrated \(count) read articles")
    }
    
    private func migrateReadDaysFromSQL(db: OpaquePointer) async throws {
        let query = "SELECT ZDATESTRING, ZISREAD FROM ZREADDAY"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let dateString = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
            let isRead = sqlite3_column_int(statement, 1) != 0
            
            let existingDescriptor = FetchDescriptor<ReadDay>(predicate: #Predicate { $0.dateString == dateString })
            let existing = try mainContext.fetch(existingDescriptor)
            
            if existing.isEmpty {
                let newDay = ReadDay(dateString: dateString, isRead: isRead)
                mainContext.insert(newDay)
                count += 1
            }
        }
        
        print("Migrated \(count) read days")
    }
}

struct DataImportView: View {
    @StateObject private var migrationService: DataMigrationService
    @State private var showingImportAlert = false
    @State private var selectedURL: URL?
    @State private var settingsURL: URL?
    
    init(context: ModelContext) {
        _migrationService = StateObject(wrappedValue: DataMigrationService(mainContext: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { selectBackupFile() }) {
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
            Button("Cancel", role: .cancel) {
                selectedURL = nil
                settingsURL = nil
            }
        } message: {
            Text("Ready to import from: \(selectedURL?.lastPathComponent ?? "backup folder"). This will merge your legacy journal and scripture progress into iCloud. This will NOT delete any existing data.")
        }
    }
    
    private func selectBackupFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Pensive Backup Folder"
        panel.message = "Select your Pensive_Manual_Backup folder (it should contain journal.store)"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            // Look for journal.store in the selected folder
            let storeURL = folderURL.appendingPathComponent("journal.store")
            if FileManager.default.fileExists(atPath: storeURL.path) {
                selectedURL = storeURL
                // Check for settings file
                let possibleSettings = folderURL.appendingPathComponent("com.joshua.pensive.plist")
                if FileManager.default.fileExists(atPath: possibleSettings.path) {
                    settingsURL = possibleSettings
                }
                showingImportAlert = true
            } else {
                migrationService.error = "No journal.store file found in selected folder"
            }
        }
    }
    
    private func startMigration() {
        guard let backupURL = selectedURL else {
            migrationService.error = "No backup file selected"
            return
        }
        
        let folderURL = backupURL.deletingLastPathComponent()
        
        Task {
            await migrationService.migrateFromLegacyBackup(
                at: backupURL,
                folderURL: folderURL,
                settingsUrl: settingsURL
            )
            
            selectedURL = nil
            settingsURL = nil
        }
    }
}
#endif
