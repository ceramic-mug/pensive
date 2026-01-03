#if os(macOS)
import SwiftUI
import SwiftData

@main
struct PensiveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var rssService = RSSService()
    
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            JournalEntry.self,
            JournalSection.self,
            ReadArticle.self
        ])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupport.appendingPathComponent("Pensive", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        let storeURL = directoryURL.appendingPathComponent("journal.store")
        let config = ModelConfiguration(url: storeURL)
        
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
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

class AppSettings: ObservableObject {
    @AppStorage("theme") var theme: AppTheme = .light
    @AppStorage("font") var font: AppFont = .sans
    @AppStorage("isDistractionFree") var isDistractionFree: Bool = false
    @AppStorage("textSize") var textSize: Double = 20
    @AppStorage("editorWidth") var editorWidth: Double = 750
    @AppStorage("horizontalPadding") var horizontalPadding: Double = 80
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
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set app icon from resources
        if let iconPath = Bundle.module.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }
    }
}
#endif
