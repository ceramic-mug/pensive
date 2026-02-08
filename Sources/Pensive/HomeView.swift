import SwiftUI

struct HomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @Binding var selectedEntryID: UUID?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var currentDate = Date()
    @State private var timer: Timer?
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
    
    // Greeting based on time of day
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    // Formatted date string
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = isCompact ? "EEEE, MMM d" : "EEEE, MMM d • h:mm a"
        return formatter.string(from: currentDate)
    }
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: isCompact ? 24 : 40) {
                Spacer()
                
                // Header Section
                VStack(spacing: 8) {
                    Text(greeting)
                        .font(.system(size: isCompact ? 32 : 42, weight: .light, design: .serif))
                        .foregroundColor(settings.theme.textColor)
                    
                    Text(dateString)
                        .font(.system(size: isCompact ? 15 : 18, weight: .medium, design: .serif))
                        .monospacedDigit()
                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                }
                
                // Tiles List
                VStack(spacing: isCompact ? 14 : 20) {
                    HomeTile(
                        title: "Scripture",
                        icon: "book",
                        color: .orange
                    ) {
                        sidebarSelection = .scripture
                    }
                    
                    HomeTile(
                        title: "Prayer",
                        icon: "flame.fill",
                        color: .green
                    ) {
                        sidebarSelection = .pray
                    }

                    HomeTile(
                        title: "Journal",
                        icon: "pencil.line",
                        color: .blue
                    ) {
                        selectedEntryID = nil
                        sidebarSelection = .journal
                    }
                    
                    HomeTile(
                        title: "Study",
                        icon: "graduationcap",
                        color: .purple
                    ) {
                        sidebarSelection = .study
                    }
                }
                .padding(.horizontal, isCompact ? 24 : 40)
                .frame(maxWidth: isCompact ? .infinity : 350)
                
                Spacer()
            }
            .padding(.top, isCompact ? 20 : 0)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentDate = Date()
            }
            currentDate = Date()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct HomeTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject var settings: AppSettings
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(getFont(size: 18))
                    .foregroundColor(settings.theme.textColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(settings.theme.textColor.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settings.theme.textColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(settings.theme.textColor.opacity(isHovered ? 0.2 : 0), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func getFont(size: Double) -> Font {
        switch settings.font {
        case .sans:
            return .system(size: size, design: .default)
        case .serif:
            return .system(size: size, design: .serif)
        case .mono:
            return .system(size: size, design: .monospaced)
        }
    }
}
