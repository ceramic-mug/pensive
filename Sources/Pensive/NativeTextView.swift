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
        textView.textContainerInset = NSSize(width: horizontalPadding, height: 20)
        
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
        
        if textView.textContainerInset.width != horizontalPadding {
            textView.textContainerInset = NSSize(width: horizontalPadding, height: 20)
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
        
        func updateHeight(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let height = usedRect.height + textView.textContainerInset.height * 2
            
            DispatchQueue.main.async {
                if self.parent.height != height {
                    self.parent.height = height
                }
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
#endif
