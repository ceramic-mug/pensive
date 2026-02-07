import SwiftUI
import SwiftData
import Combine

@main
struct PensiveApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @StateObject private var settings = AppSettings()
    @StateObject private var rssService = RSSService()
    
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            JournalEntry.self,
            JournalSection.self,
            ReadArticle.self,
            ReadDay.self,
            RSSFeed.self
        ])
        
        // For CloudKit sync, ModelConfiguration should be robust but lightweight.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(rssService)
                .modelContainer(container)
                .onAppear {
                    // Setup preference mirroring on a background task to avoid blocking launch
                    Task.detached(priority: .utility) {
                        await UbiquitousStore.shared.setupMirroring(keys: [
                            "theme", "font", "textSize", "editorWidth", "marginPercentage", "esvApiKey"
                        ])
                    }
                }
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 400)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}

class AppSettings: ObservableObject {
    @AppStorage("theme") var theme: AppTheme = .light
    @AppStorage("font") var font: AppFont = .sans
    @AppStorage("textSize") var textSize: Double = 20
    @AppStorage("editorWidth") var editorWidth: Double = 750
    @AppStorage("marginPercentage") var marginPercentage: Double = 0.15
    @AppStorage("esvApiKey") var esvApiKey: String = "623bc74f74405b90cf7e98cc74215d2ea217f13a"
    
    // Study Settings
    @AppStorage("studyLayoutStyle") var studyLayoutStyle: StudyLayoutStyle = .grid
    @AppStorage("studyFilter") var studyFilter: StudyFilter = .all
    @AppStorage("studyColumns") var studyColumns: Int = 2
}

enum StudyLayoutStyle: String, CaseIterable, Identifiable {
    case list, grid
    var id: String { self.rawValue }
}

enum StudyFilter: String, CaseIterable, Identifiable {
    case all, unread
    var id: String { self.rawValue }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, sepia
    var id: String { self.rawValue }
    
    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .dark: return Color(red: 0.16, green: 0.16, blue: 0.16)
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.85)
        }
    }
    
    var textColor: Color {
        switch self {
        case .light: return .black
        case .dark: return .white
        case .sepia: return Color(red: 0.26, green: 0.21, blue: 0.17)
        }
    }
    
    var selectionColor: Color {
        switch self {
        case .light:
            // Soft Blue-Grey Highlight
            return Color(red: 0.88, green: 0.92, blue: 0.97)
        case .dark:
            // Deep Slate Highlight (Avoiding jarring blue)
            return Color(red: 0.26, green: 0.28, blue: 0.32)
        case .sepia:
            // Warm Almond Highlight
            return Color(red: 0.89, green: 0.84, blue: 0.76)
        }
    }
}

enum AppFont: String, CaseIterable, Identifiable {
    case sans, serif, mono
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .sans: return "system"
        case .serif: return "Iowan Old Style"
        case .mono: return "SF Mono"
        }
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set app icon from resources
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.toggleFullScreen(nil)
            }
        }
    }
}
#endif
