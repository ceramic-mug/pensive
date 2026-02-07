import SwiftUI
import SwiftData

struct DivineHoursView: View {
    @StateObject private var service = DivineHoursService()
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            settings.theme.backgroundColor
                .ignoresSafeArea()
            
            if service.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Gathering the Hours...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let office = service.currentOffice {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 40) {
                        // Header
                        ZStack(alignment: .center) {
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(settings.theme.textColor.opacity(0.6))
                                        .padding(10)
                                        .background(Circle().fill(settings.theme.textColor.opacity(0.05)))
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 8) {
                                Text(office.title)
                                    .font(.system(size: 34, weight: .light, design: .serif))
                                    .foregroundColor(settings.theme.textColor)
                                    .multilineTextAlignment(.center)
                                
                                Text(office.subtitle)
                                    .font(.system(size: 16, weight: .medium, design: .serif).italic())
                                    .foregroundColor(settings.theme.textColor.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // Sections
                        VStack(alignment: .leading, spacing: 50) {
                            ForEach(office.sections) { section in
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(section.title.uppercased())
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.accentColor)
                                        .kerning(1.5)
                                    
                                    Text(LocalizedStringKey(section.content))
                                        .font(.system(size: settings.textSize, design: .serif))
                                        .foregroundColor(settings.theme.textColor)
                                        .lineSpacing(8)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    if let citation = section.citation {
                                        Text(citation)
                                            .font(.system(size: settings.textSize * 0.75, design: .serif).italic())
                                            .foregroundColor(settings.theme.textColor.opacity(0.5))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                        .frame(maxWidth: 800)
                        .padding(.bottom, 150)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if let error = service.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.headline)
                    Button("Retry") {
                        service.fetchDivineHours()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No data available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
        }
        .navigationTitle("")
        .onAppear {
            service.fetchDivineHours()
            markAsPrayed()
        }
    }
    
    private func markAsPrayed() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        if let existing = try? modelContext.fetch(FetchDescriptor<PrayedDay>(predicate: #Predicate<PrayedDay> { $0.dateString == dateString })).first {
            existing.isPrayed = true
        } else {
            modelContext.insert(PrayedDay(dateString: dateString))
        }
        try? modelContext.save()
    }
}

