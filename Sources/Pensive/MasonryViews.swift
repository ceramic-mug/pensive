import SwiftUI

struct MasonryVStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    @Environment(\.horizontalSizeClass) var sizeClass
    let columns: Int
    let data: Data
    let content: (Data.Element) -> Content
    
    init(columns: Int = 2, data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.columns = columns
        self.data = data
        self.content = content
    }
    
    var body: some View {
        let actualColumns = sizeClass == .compact ? 1 : max(1, columns)
        
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<actualColumns, id: \.self) { columnIndex in
                LazyVStack(spacing: 16) {
                    ForEach(columnItems(for: columnIndex, actualColumns: actualColumns)) { item in
                        content(item)
                    }
                }
            }
        }
    }
    
    private func columnItems(for index: Int, actualColumns: Int) -> [Data.Element] {
        var items = [Data.Element]()
        var currentIndex = 0
        for item in data {
            if currentIndex % actualColumns == index {
                items.append(item)
            }
            currentIndex += 1
        }
        return items
    }
}
