import SwiftUI

struct SymbolItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
}

let symbolMap = [
    SymbolItem(name: "rightarrow", symbol: "→"),
    SymbolItem(name: "leftarrow", symbol: "←"),
    SymbolItem(name: "uparrow", symbol: "↑"),
    SymbolItem(name: "downarrow", symbol: "↓"),
    SymbolItem(name: "double right", symbol: "⇒"),
    SymbolItem(name: "double left", symbol: "⇐"),
    SymbolItem(name: "paragraph", symbol: "❡"),
    SymbolItem(name: "section", symbol: "§"),
    SymbolItem(name: "copyright", symbol: "©"),
    SymbolItem(name: "registered", symbol: "®"),
    SymbolItem(name: "trademark", symbol: "™"),
    SymbolItem(name: "bullet", symbol: "•"),
    SymbolItem(name: "degree", symbol: "°"),
    SymbolItem(name: "plusminus", symbol: "±"),
    SymbolItem(name: "multiply", symbol: "×"),
    SymbolItem(name: "divide", symbol: "÷"),
    SymbolItem(name: "approx", symbol: "≈"),
    SymbolItem(name: "notequal", symbol: "≠"),
    SymbolItem(name: "lte", symbol: "≤"),
    SymbolItem(name: "gte", symbol: "≥"),
    SymbolItem(name: "euro", symbol: "€"),
    SymbolItem(name: "pound", symbol: "£"),
    SymbolItem(name: "yen", symbol: "¥"),
    SymbolItem(name: "cent", symbol: "¢"),
    SymbolItem(name: "infinity", symbol: "∞"),
    SymbolItem(name: "check", symbol: "✓"),
    SymbolItem(name: "cross", symbol: "✗"),
    SymbolItem(name: "emdash", symbol: "—"),
    SymbolItem(name: "endash", symbol: "–"),
    SymbolItem(name: "ellipsis", symbol: "…")
].sorted { $0.name < $1.name }

struct SymbolPicker: View {
    @Binding var query: String
    @Binding var selectedIndex: Int
    var onSelect: (SymbolItem) -> Void
    
    var filteredSymbols: [SymbolItem] {
        if query.isEmpty { return symbolMap }
        return symbolMap.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if filteredSymbols.isEmpty {
                Text("No matching symbols")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(filteredSymbols.enumerated()), id: \.element.id) { index, item in
                                SymbolRow(item: item, isSelected: index == selectedIndex) {
                                    onSelect(item)
                                }
                                .id(index)
                            }
                        }
                        .padding(4)
                    }
                    .onChange(of: selectedIndex) { old, new in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 220, height: 280)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
}

struct SymbolRow: View {
    let item: SymbolItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        }
        #if os(macOS)
        return isHovered ? Color.primary.opacity(0.05) : Color.clear
        #else
        return Color.clear
        #endif
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(item.symbol)
                    .font(.system(size: 20))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                    .cornerRadius(6)
                
                Text(item.name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor.opacity(0.6))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(rowBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
    }
}
