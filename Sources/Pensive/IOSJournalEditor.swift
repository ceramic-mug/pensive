import SwiftUI

#if os(iOS)
import UIKit

struct IOSJournalEditor: View {
    @Bindable var section: JournalSection
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    
    @State private var draftText: String = ""
    @State private var saveTask: Task<Void, Never>? = nil
    
    var body: some View {
        JournalUITextView(
            text: $draftText,
            fontName: fontName,
            fontSize: fontSize,
            textColor: textColor,
            selectionColor: selectionColor,
            horizontalPadding: horizontalPadding
        )
        .ignoresSafeArea(.keyboard, edges: .bottom) // Let the text view handle its own keyboard padding
        .onAppear {
            draftText = section.content
        }
        .onDisappear {
            saveImmediately()
        }
        .onChange(of: draftText) { oldValue, newValue in
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        section.content = draftText
                    }
                }
            }
        }
    }
    
    private func saveImmediately() {
        saveTask?.cancel()
        section.content = draftText
    }
}

struct JournalUITextView: UIViewRepresentable {
    @Binding var text: String
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isScrollEnabled = true // Enable native scrolling to fix overflow and jumpiness
        textView.backgroundColor = .clear
        
        // Critical for fixing overflow
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        
        // Use consistent padding - reduced bottom since it handles its own scrolling
        textView.textContainerInset = UIEdgeInsets(top: 20, left: horizontalPadding + 20, bottom: 20, right: horizontalPadding + 20)
        
        // Better UX: Done button on keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        toolbar.items = [flex, done]
        textView.inputAccessoryView = toolbar
        
        textView.keyboardDismissMode = .interactive
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        let font: UIFont
        if fontName == "SF Mono" || fontName == "mono" || fontName == "systemMono" {
             font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else if fontName == "system" {
            font = .systemFont(ofSize: fontSize)
        } else {
            font = UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }
        uiView.font = font
        uiView.textColor = UIColor(textColor)
        uiView.tintColor = UIColor(selectionColor)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: JournalUITextView
        
        init(_ parent: JournalUITextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
        
        // Handle cursor placement logic if needed
        func textViewDidBeginEditing(_ textView: UITextView) {
            // Optional: Scroll to cursor or preserve position
        }
        
        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
#endif
