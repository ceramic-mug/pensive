import SwiftUI

struct MasonryVStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let columns: Int
    let data: Data
    let content: (Data.Element) -> Content
    
    init(columns: Int = 2, data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.columns = columns
        self.data = data
        self.content = content
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                LazyVStack(spacing: 16) {
                    ForEach(columnItems(for: columnIndex)) { item in
                        content(item)
                    }
                }
            }
        }
    }
    
    private func columnItems(for index: Int) -> [Data.Element] {
        // Distribute items round-robin style
        // Index 0: 0, 2, 4...
        // Index 1: 1, 3, 5...
        var items = [Data.Element]()
        var currentIndex = 0
        for item in data {
            if currentIndex % columns == index {
                items.append(item)
            }
            currentIndex += 1
        }
        return items
    }
}
