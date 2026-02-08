import SwiftUI

struct UnifiedModuleHeader: View {
    let title: String
    let subtitle: String?
    var showBackButton: Bool = true
    var onBack: (() -> Void)?
    var onShowSettings: () -> Void
    
    @EnvironmentObject var settings: AppSettings
    @Environment(\.horizontalSizeClass) var sizeClass
    
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundColor(settings.theme.textColor)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(getFont(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if !isCompact && showBackButton {
                    Button(action: {
                        if let onBack = onBack {
                            onBack()
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(settings.theme.textColor.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
                
                Button(action: onShowSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(settings.theme.backgroundColor)
        .zIndex(10)
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
