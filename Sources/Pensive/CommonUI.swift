import SwiftUI

// MARK: - Width Preference Key
struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extensions
extension View {
    func maxInternalWidth(_ width: CGFloat) -> some View {
        self.frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            )
            #if os(macOS)
            .padding(.horizontal, max(0, ((NSScreen.main?.visibleFrame.width ?? 1200) - width) / 4))
            #else
            .padding(.horizontal, 16) // Default padding for iOS
            #endif
    }
}
