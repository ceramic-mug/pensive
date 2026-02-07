#if os(macOS)
import SwiftUI
import AppKit

struct NativeTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    
    // Symbol Picker State
    @Binding var isPickerPresented: Bool
    @Binding var pickerQuery: String
    @Binding var pickerPosition: CGPoint
    var onCommand: (ControlCommand) -> Bool // Return true if handled
    
    enum ControlCommand {
        case moveUp, moveDown, confirm, complete, cancel
    }
    
    func makeNSView(context: Context) -> CommandTextView {
        let textView = CommandTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.focusRingType = .none
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: horizontalPadding + 20, height: 20)
        
        // Listen for frame changes to recalculate height
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
        
        return textView
    }
    
    func updateNSView(_ textView: CommandTextView, context: Context) {
        context.coordinator.parent = self
        textView.onCommand = onCommand
        
        if textView.string != text {
            textView.string = text
            context.coordinator.updateHeight(textView)
        }
        
        let font: NSFont
        if fontName == "SF Mono" || fontName == "mono" {
            font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else if fontName == "system" {
            font = .systemFont(ofSize: fontSize)
        } else {
            font = NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }
        
        if textView.font != font {
            textView.font = font
            context.coordinator.updateHeight(textView)
        }
        
        textView.textColor = NSColor(textColor)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(selectionColor),
            .foregroundColor: NSColor(textColor)
        ]
        
        let newInset = NSSize(width: horizontalPadding + 20, height: 20)
        if textView.textContainerInset.width != newInset.width {
            textView.textContainerInset = newInset
            context.coordinator.updateHeight(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextView
        
        init(_ parent: NativeTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let content = textView.string
            
            if parent.text != content {
                parent.text = content
            }
            
            updateHeight(textView)
            
            // Trigger detection
            let range = textView.selectedRange()
            if range.length == 0 && range.location > 0 {
                let nsString = content as NSString
                let textBeforeCursor = nsString.substring(to: range.location)
                
                if let lastSlashIndex = textBeforeCursor.lastIndex(of: "/") {
                    let query = String(textBeforeCursor.suffix(from: textBeforeCursor.index(after: lastSlashIndex)))
                    
                    // Check if "/" is at start of line or after space
                    let prefix = textBeforeCursor.prefix(upTo: lastSlashIndex)
                    if prefix.isEmpty || prefix.hasSuffix(" ") || prefix.hasSuffix("\n") {
                        if !query.contains(" ") {
                            parent.pickerQuery = query
                            parent.isPickerPresented = true
                            
                            // Calculate cursor position for popover
                            if let layoutManager = textView.layoutManager,
                               let textContainer = textView.textContainer {
                                let rect = layoutManager.boundingRect(forGlyphRange: NSMakeRange(range.location - 1, 1), in: textContainer)
                                let screenRect = textView.convert(rect, to: nil)
                                if let window = textView.window {
                                    let windowRect = window.convertToScreen(screenRect)
                                    parent.pickerPosition = CGPoint(x: windowRect.midX, y: windowRect.origin.y)
                                }
                            }
                            return
                        }
                    }
                }
            }
            if parent.isPickerPresented {
                parent.isPickerPresented = false
            }
        }
        
        @objc func frameDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateHeight(textView)
        }

        private var isUpdatingHeight = false

        func updateHeight(_ textView: NSTextView) {
            guard !isUpdatingHeight else { return }
            
            guard let container = textView.textContainer,
                  let layoutManager = textView.layoutManager else {
                return
            }
            
            isUpdatingHeight = true
            layoutManager.ensureLayout(for: container)
            let usedRect = layoutManager.usedRect(for: container)
            let newHeight = usedRect.height + textView.textContainerInset.height * 2
            
            if abs(parent.height - newHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.height = max(100, newHeight) // Ensure a minimum height for visibility
                    self.isUpdatingHeight = false
                }
            } else {
                isUpdatingHeight = false
            }
        }
    }
}

class CommandTextView: NSTextView {
    var onCommand: ((NativeTextView.ControlCommand) -> Bool)?
    
    override func doCommand(by selector: Selector) {
        if let onCommand = onCommand {
            switch selector {
            case #selector(moveUp(_:)):
                if onCommand(.moveUp) { return }
            case #selector(moveDown(_:)):
                if onCommand(.moveDown) { return }
            case #selector(insertNewline(_:)):
                if onCommand(.confirm) { return }
            case #selector(cancelOperation(_:)):
                if onCommand(.cancel) { return }
            case #selector(insertTab(_:)):
                if onCommand(.complete) { return }
            default:
                break
            }
        }
        super.doCommand(by: selector)
    }
}

extension String {
    func lastIndex(of char: Character) -> String.Index? {
        return self.range(of: String(char), options: .backwards)?.lowerBound
    }
}
#elseif os(iOS)
import SwiftUI
import UIKit

struct NativeTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var selectionColor: Color
    var horizontalPadding: CGFloat
    
    // Symbol Picker State
    @Binding var isPickerPresented: Bool
    @Binding var pickerQuery: String
    @Binding var pickerPosition: CGPoint
    var onCommand: (ControlCommand) -> Bool 
    
    enum ControlCommand {
        case moveUp, moveDown, confirm, complete, cancel
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isScrollEnabled = false // Allows auto-growth
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: horizontalPadding + 20, bottom: 20, right: horizontalPadding + 20)
        
        // Toolbar for closing keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        toolbar.items = [flex, done]
        textView.inputAccessoryView = toolbar
        
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        
        if uiView.text != text {
            uiView.text = text
        }
        
        // Font
        let font: UIFont
        if fontName == "SF Mono" || fontName == "mono" {
            font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else if fontName == "system" {
            font = .systemFont(ofSize: fontSize)
        } else {
            font = UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }
        if uiView.font != font {
            uiView.font = font
        }
        
        uiView.textColor = UIColor(textColor)
        uiView.tintColor = UIColor(selectionColor)
        
        updateHeight(uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func updateHeight(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
        if abs(height - size.height) > 1 {
            DispatchQueue.main.async {
                self.height = size.height
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeTextView

        init(_ parent: NativeTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let content = textView.text ?? ""
            if parent.text != content {
                parent.text = content
            }
            parent.updateHeight(textView)
            
            // Symbol Trigger Detection
            let range = textView.selectedRange
            if range.length == 0 && range.location > 0 {
                let nsString = content as NSString
                let textBeforeCursor = nsString.substring(to: range.location)
                
                if let lastSlashIndex = textBeforeCursor.lastIndex(of: "/") {
                    let query = String(textBeforeCursor.suffix(from: textBeforeCursor.index(after: lastSlashIndex)))
                    
                    // Check if "/" is at start of line or after space
                    let prefix = textBeforeCursor.prefix(upTo: lastSlashIndex)
                    if prefix.isEmpty || prefix.hasSuffix(" ") || prefix.hasSuffix("\n") {
                        if !query.contains(" ") {
                            parent.pickerQuery = query
                            parent.isPickerPresented = true
                            
                            // Calculate cursor position for popover/overlay
                            if let selectedRange = textView.selectedTextRange {
                                let rect = textView.caretRect(for: selectedRange.end)
                                parent.pickerPosition = textView.convert(rect.origin, to: nil)
                            }
                            return
                        }
                    }
                }
            }
            if parent.isPickerPresented {
                parent.isPickerPresented = false
            }
        }
        
        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
#endif
