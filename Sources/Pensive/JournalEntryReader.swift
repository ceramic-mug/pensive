import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct JournalEntryReader: View {
    let entry: JournalEntry
    var onClose: () -> Void
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        ZStack {
            // Subtle dimming background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut) { onClose() } }
                .transition(.opacity)
            
            // The Card
            VStack(spacing: 0) {
                HStack {
                    Text(entry.date.formatted(date: .complete, time: .omitted))
                        .font(settings.font.swiftUIFont(size: 18, weight: Font.Weight.semibold))
                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // Export Button
                        Button(action: shareEntry) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                        }
                        
                        Button(action: { withAnimation(.easeInOut) { onClose() } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(settings.font.swiftUIFont(size: 14, weight: Font.Weight.bold))
                            .foregroundColor(.accentColor)
                        
                        if let sections = entry.sections, !sections.isEmpty {
                            ForEach(sections) { section in
                                Text(section.content)
                                    .font(settings.font.swiftUIFont(size: 18))
                                    .lineSpacing(6)
                                    .foregroundColor(settings.theme.textColor)
                            }
                        } else {
                            Text(entry.content)
                                .font(settings.font.swiftUIFont(size: 18))
                                .lineSpacing(6)
                                .foregroundColor(settings.theme.textColor)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 600, maxHeight: 600)
            .background(settings.theme.backgroundColor)
            .cornerRadius(24)
            .shadow(radius: 30)
            .padding()
            .padding(.bottom, 20)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(100)
    }
    
    private func shareEntry() {
        let dateHeader = entry.date.formatted(date: .long, time: .shortened)
        let bodyText = (entry.sections?.isEmpty == false) ? entry.sections!.compactMap(\.content).joined(separator: "\n\n") : entry.content
        let fullText = "\(dateHeader)\n\n\(bodyText)"
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [fullText], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
        #endif
    }
}
