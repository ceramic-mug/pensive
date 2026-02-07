import SwiftUI

struct HomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem?
    @Binding var selectedEntryID: UUID?
    @EnvironmentObject var settings: AppSettings
    @State private var currentDate = Date()
    @State private var timer: Timer?
    
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
        formatter.dateFormat = "EEEE, MMM d • h:mm a"
        return formatter.string(from: currentDate)
    }
    
    var body: some View {
        ZStack {
            settings.theme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Header Section
                VStack(spacing: 8) {
                    Text(greeting)
                        .font(.system(size: 42, weight: .light, design: .serif))
                        .foregroundColor(settings.theme.textColor)
                    
                    Text(dateString)
                        .font(.system(size: 18, weight: .medium, design: .serif)) // Monospaced numbers for stable clock
                        .monospacedDigit()
                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                }
                
                // Tiles List
                VStack(spacing: 20) {
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
                .padding(.horizontal, 40)
                .frame(maxWidth: 350)
                
                Spacer()
            }
        }
        .overlay(alignment: .topTrailing) {
            #if !os(macOS)
            Button(action: { 
                NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .padding()
            }
            .padding(.top, 10)
            #endif
        }
        .onAppear {
            // Update time every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentDate = Date()
            }
            // Update immediately on appear to catch seconds drift
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
