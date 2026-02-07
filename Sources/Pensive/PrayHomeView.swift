import SwiftUI

struct PrayHomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @EnvironmentObject var settings: AppSettings
    @State private var presentationPath = NavigationPath()
    @State private var showActivity = false
    
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
                        // Back Arrow (Fixed)
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

                        ScrollView {
                            VStack(spacing: 40) {
                                Spacer(minLength: 60)
                                
                                // Content Section
                                VStack(spacing: 12) {
                                    Text("Prayer")
                                        .font(.system(size: 42, weight: .light, design: .serif))
                                        .foregroundColor(settings.theme.textColor)
                                    
                                    Text("Cast your burden on the Lord,\nand he will sustain you.")
                                        .multilineTextAlignment(.center)
                                        .font(.system(size: 18, weight: .medium, design: .serif))
                                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                                }
                                
                                // Tiles Grid
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
                                
                                
                                Spacer(minLength: 60)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geo.size.height)
                        }
                    }
                }
            }
            .overlay {
                if showActivity {
                    activityOverlay
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
    }
    
    private var activityOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showActivity = false } }
            
            VStack {
                Spacer()
                UnifiedHeatmapView()
                    .padding()
                    .background(settings.theme.backgroundColor)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                    .shadow(radius: 20)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
