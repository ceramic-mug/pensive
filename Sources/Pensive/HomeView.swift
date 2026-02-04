import SwiftUI

struct HomeView: View {
    @Binding var sidebarSelection: ContentView.SidebarItem
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
                
                // Tiles Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)], spacing: 20) {
                    HomeTile(
                        title: "Journal",
                        icon: "pencil.line",
                        color: .blue
                    ) {
                        selectedEntryID = nil
                        sidebarSelection = .journal
                    }
                    
                    HomeTile(
                        title: "Scripture",
                        icon: "book",
                        color: .orange
                    ) {
                        sidebarSelection = .scripture
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
                .frame(maxWidth: 900)
                
                Spacer()
            }
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
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(settings.theme.textColor)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settings.theme.textColor.opacity(0.05))
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
}
