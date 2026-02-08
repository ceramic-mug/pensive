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
                    ZStack(alignment: .topLeading) {
                        // Back Arrow (Only on non-compact iOS and macOS)
                        if !isCompact {
                            HStack {
                                Button(action: { sidebarSelection = .home }) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                                        .padding(10)
                                        .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
                                }
                                .buttonStyle(.plain)
                                .padding()
                                Spacer()
                            }
                            .padding(.top, 40)
                            .zIndex(2)
                        }

                        VStack(spacing: 0) {
                            if isCompact {
                                iosHeader
                            }
                            
                            ScrollView {
                                VStack(spacing: isCompact ? 24 : 40) {
                                    Spacer(minLength: isCompact ? 20 : 60)
                                    
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
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settings)
            }
        }
    }
    
    private var iosHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prayer")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundColor(settings.theme.textColor)
                
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(getFont(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(settings.theme.backgroundColor)
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
