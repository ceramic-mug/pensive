import SwiftUI

struct AbstractCardView: View {
    let section: AbstractSection
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title.uppercased())
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundColor(.accentColor)
                .padding(.bottom, 2)
            
            Text(section.content)
                .font(.system(.callout, design: .rounded))
                .foregroundColor(settings.theme.textColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settings.theme.backgroundColor.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
