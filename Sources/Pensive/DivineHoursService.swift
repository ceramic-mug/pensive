import Foundation
import Combine

struct DivineOffice: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let sections: [PrayerSection]
    
    struct PrayerSection: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let citation: String?
    }
}

class DivineHoursService: ObservableObject {
    @Published var currentOffice: DivineOffice?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchDivineHours() {
        guard let url = URL(string: "https://www.a2cc.org/resources/pray-the-divine-hours") else { return }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data, let html = String(data: data, encoding: .utf8) else {
                    self?.errorMessage = "Failed to load content"
                    return
                }
                
                self?.parseHTML(html)
            }
        }.resume()
    }
    
    private func parseHTML(_ html: String) {
        // First, isolate the main content container to avoid footer/nav leakage
        let containerPattern = "<div[^>]*class=\"[^\"]*max-w-4xl\\s+mx-auto[^\"]*\"[^>]*>(.*?)</div>\\s*</div>\\s*</div>\\s*</div>\\s*</main>"
        let mainContent = extractMatch(from: html, pattern: containerPattern, options: [.dotMatchesLineSeparators]) ?? html
        
        let title = cleanEntities(extractMatch(from: mainContent, pattern: "<h1[^>]*>([^<]+)</h1>") ?? "The Divine Hours")
        let subtitle = cleanEntities(extractMatch(from: mainContent, pattern: "<h1[^>]*>.*?</h1>\\s*<p[^>]*>([^<]+)</p>", options: [.dotMatchesLineSeparators]) ?? "")
        
        var sections: [DivineOffice.PrayerSection] = []
        
        // Split by the prose container div within mainContent
        let sectionTag = "class=\"prose max-w-none\""
        let parts = mainContent.components(separatedBy: sectionTag)
        
        for part in parts.dropFirst() {
            // Extract H2 Title
            let sectionTitle = cleanEntities(extractMatch(from: part, pattern: "<h2[^>]*>([^<]+)</h2>") ?? "")
            if sectionTitle.isEmpty { continue }
            
            // Extract H3 Title (if any)
            let subHeader = cleanEntities(extractMatch(from: part, pattern: "<h3[^>]*>([^<]+)</h3>") ?? "")
            
            // Extract all whitespace-pre-line content blocks
            var contentParts: [String] = []
            let contentRegex = try? NSRegularExpression(pattern: "<div[^>]*class=\"[^\"]*whitespace-pre-line[^\"]*\"[^>]*>(.*?)</div>", options: [.dotMatchesLineSeparators])
            if let regex = contentRegex {
                let nsPart = part as NSString
                let contentMatches = regex.matches(in: part, options: [], range: NSRange(location: 0, length: nsPart.length))
                for cMatch in contentMatches {
                    contentParts.append(nsPart.substring(with: cMatch.range(at: 1)))
                }
            }
            
            // Prepend subheader to first content block if exists
            var fullContent = ""
            if !subHeader.isEmpty {
                fullContent += "**\(subHeader)**\n\n"
            }
            fullContent += contentParts.joined(separator: "\n\n")
            
            let cleanedContent = cleanContent(fullContent, sectionTitle: sectionTitle)
            
            // Extract all citations
            var citationParts: [String] = []
            let citationRegex = try? NSRegularExpression(pattern: "<p[^>]*class=\"[^\"]*text-sm[^\"]*text-gray-500[^\"]*italic[^\"]*\"[^>]*>(.*?)</p>", options: [.dotMatchesLineSeparators])
            if let regex = citationRegex {
                let nsPart = part as NSString
                let citationMatches = regex.matches(in: part, options: [], range: NSRange(location: 0, length: nsPart.length))
                for citMatch in citationMatches {
                    let citText = nsPart.substring(with: citMatch.range(at: 1))
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        // Strip leading dashes (unicode em-dash, en-dash, or hyphen)
                        .replacingOccurrences(of: "^[—–-]+\\s*", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "&mdash;", with: "")
                        .replacingOccurrences(of: "<!-- -->", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let cleanedCit = cleanEntities(citText)
                        .replacingOccurrences(of: "\n", with: " ")
                    
                    if !cleanedCit.isEmpty {
                        citationParts.append(cleanedCit)
                    }
                }
            }
            
            var citation: String?
            if !citationParts.isEmpty {
                citation = "— " + citationParts.joined(separator: " | ")
            }
            
            sections.append(DivineOffice.PrayerSection(title: sectionTitle, content: cleanedContent, citation: citation))
        }
        
        self.currentOffice = DivineOffice(title: title, subtitle: subtitle, sections: sections)
    }
    
    private func cleanEntities(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cleanContent(_ raw: String, sectionTitle: String) -> String {
        var content = cleanEntities(raw)
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&mdash;", with: "—")
        
        // Remove residual tags
        content = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        let proseSections = ["A Reading", "The Prayer Appointed for the Week", "The Concluding Prayer of the Church", "The Collect"]
        let isProseOnly = proseSections.contains(where: { sectionTitle.localizedCaseInsensitiveContains($0) })
        
        // Collapse single newlines into spaces, preserve double newlines
        // This makes psalms, hymns, and prose flow naturally on small screens
        // First, protect double newlines
        let placeholder = "[[PARAGRAPH_BREAK]]"
        content = content.replacingOccurrences(of: "\n\n", with: placeholder)
        // Collapse single newlines
        content = content.replacingOccurrences(of: "\n", with: " ")
        // Restore paragraph breaks
        content = content.replacingOccurrences(of: placeholder, with: "\n\n")
        
        // Normalize whitespace
        content = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        
        // Limit maximum consecutive newlines to 2
        while content.contains("\n\n\n") {
            content = content.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractMatch(from string: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsString = string as NSString
        if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) {
            return nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
