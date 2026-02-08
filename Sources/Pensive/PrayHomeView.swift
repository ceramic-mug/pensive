import SwiftUI

struct PrayHomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var presentationPath = NavigationPath()
    @State private var showSettings = false
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
    
    enum PraySubSection {
        case divineHours
        case personal
    }
    
    var body: some View {
        NavigationStack(path: $presentationPath) {
            ZStack {
                settings.theme.backgroundColor
                    .ignoresSafeArea()
                
                GeometryReader { geo in
                UnifiedModuleHeader(
                    title: "Prayer",
                    subtitle: Date().formatted(date: .long, time: .omitted),
                    onBack: { sidebarSelection = .home },
                    onShowSettings: { showSettings = true }
                )
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: isCompact ? 24 : 40) {
                            Spacer(minLength: isCompact ? 10 : 80)
                                    
                                    // Content Section
                                    VStack(spacing: 12) {
                                        Text("Cast your burden on the Lord,\nand he will sustain you.")
                                            .multilineTextAlignment(.center)
                                            .font(.system(size: isCompact ? 15 : 18, weight: .medium, design: .serif))
                                            .foregroundColor(settings.theme.textColor.opacity(0.6))
                                    }
                                
                                // Tiles Grid - adaptive for iOS
                                if isCompact {
                                    VStack(spacing: 14) {
                                        HomeTile(
                                            title: "Divine Hours",
                                            icon: "clock.fill",
                                            color: .blue
                                        ) {
                                            presentationPath.append(PraySubSection.divineHours)
                                        }
                                        
                                        HomeTile(
                                            title: "Personal",
                                            icon: "person.fill",
                                            color: .green
                                        ) {
                                            presentationPath.append(PraySubSection.personal)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                } else {
                                    HStack {
                                        Spacer()
                                        LazyVGrid(columns: [GridItem(.fixed(280), spacing: 20), GridItem(.fixed(280), spacing: 20)], spacing: 20) {
                                            HomeTile(
                                                title: "Divine Hours",
                                                icon: "clock.fill",
                                                color: .blue
                                            ) {
                                                presentationPath.append(PraySubSection.divineHours)
                                            }
                                            
                                            HomeTile(
                                                title: "Personal",
                                                icon: "person.fill",
                                                color: .green
                                            ) {
                                                presentationPath.append(PraySubSection.personal)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 40)
                                    .frame(maxWidth: 900)
                                }
                                
                                Spacer(minLength: isCompact ? 40 : 60)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geo.size.height - (isCompact ? 80 : 0))
                        }
                    }
                }
            }
            .navigationDestination(for: PraySubSection.self) { section in
                switch section {
                case .divineHours:
                    DivineHoursView()
                case .personal:
                    PersonalPrayerView()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settings)
            }
        }
    }
    

    private func getFont(size: Double, weight: Font.Weight = .regular) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
