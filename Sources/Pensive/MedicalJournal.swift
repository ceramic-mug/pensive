import Foundation
import SwiftData

@Model
class ReadArticle {
    var url: String = ""
    var title: String = ""
    var category: String = ""
    var publicationName: String = ""
    var dateRead: Date = Date()
    var isFlagged: Bool = false
    
    init(url: String, title: String, category: String, publicationName: String) {
        self.url = url
        self.title = title
        self.category = category
        self.publicationName = publicationName
        self.dateRead = Date()
    }
}
import Combine

struct MedicalJournal: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let rssURL: URL
    let category: String
    
    static let defaults: [MedicalJournal] = [
        MedicalJournal(name: "NEJM", rssURL: URL(string: "https://www.nejm.org/action/showFeed?jc=nejm&type=etoc&feed=rss")!, category: "Current Issues"),
        MedicalJournal(name: "AAP Pediatrics", rssURL: URL(string: "https://publications.aap.org/rss/site_1000005/1000005.xml")!, category: "Current Issues"),
        MedicalJournal(name: "Annals of Internal Medicine", rssURL: URL(string: "https://www.acpjournals.org/action/showFeed?type=etoc&feed=rss&jc=aim")!, category: "Current Issues"),
        MedicalJournal(name: "The Lancet", rssURL: URL(string: "https://www.thelancet.com/rssfeed/lancet_current.xml")!, category: "Current Issues")
    ]
}

struct AbstractSection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let content: String
}

struct RSSItem: Identifiable, Hashable {
    let id = UUID()
    var title: String = ""
    var link: String = ""
    var description: String = ""
    
    var cleanTitle: String {
        title.strippingHTMLTags()
    }
    
    var abstractSections: [AbstractSection]? {
        let cleanText = description // Use raw description to preserve some breaks if possible, or use cleanDescription? 
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<p>", with: "\n")
            .replacingOccurrences(of: "</p>", with: "\n")
            .strippingHTMLTags()
        
        return RSSItem.parseAbstractSections(from: cleanText)
    }
    
    static func parseAbstractSections(from text: String) -> [AbstractSection]? {
        // Cleaning specifically for Pediatrics and general cleanliness
        // AAP Pediatrics often prefixes with "Abstract" and then just newlines.
        var cleanText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.hasPrefix("Abstract") {
            cleanText = String(cleanText.dropFirst("Abstract".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Enhance readability by ensuring spacing around common headers if they are smashed
        // This is a heuristic.
        
        // Robust Regex Strategy:
        // Match a sequence of UPPERCASE (at least 3 chars) followed by specific separators.
        // Or specific known keywords even if not fully consistent.
        
        // We look for:
        // (Start of line OR Period+Space) + (HEADER) + (Colon OR Space+Dash OR Newline OR Space+Capital)
        
        // Allow list:
        let knownHeaders = [
            "BACKGROUND", "METHODS", "RESULTS", "CONCLUSIONS", "OBJECTIVE", 
            "DESIGN", "SETTING", "PATIENTS", "INTERVENTIONS", "MEASUREMENTS", 
            "LIMITATIONS", "DATA SOURCES", "STUDY SELECTION", "DATA EXTRACTION",
            "DATA SYNTHESIS", "PARTICIPANTS", "MAIN OUTCOME MEASURES", "REVIEW METHODS",
            "IMPORTANCE", "CONCLUSIONS AND RELEVANCE"
        ]
        
        let headerPattern = knownHeaders.joined(separator: "|")
        let pattern = "(?i)(^|\\.|\\n)\\s*(\(headerPattern))(:|\\s-|\\n|\\s+(?=[A-Z0-9]))"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        let matches = regex.matches(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.utf16.count))
        
        if matches.isEmpty { return nil }
        
        var sections: [AbstractSection] = []
        
        for i in 0..<matches.count {
            let match = matches[i]
            
            // Group 2 is the Header Name
            if match.numberOfRanges > 2 {
                let headerRange = match.range(at: 2)
                
                if let swiftRange = Range(headerRange, in: cleanText) {
                    let headerTitle = String(cleanText[swiftRange]).capitalized
                    
                    // Content starts after the full match
                    let contentStartIndex = Range(match.range, in: cleanText)!.upperBound
                    let contentEndIndex: String.Index
                    
                    if i + 1 < matches.count {
                        contentEndIndex = Range(matches[i+1].range, in: cleanText)!.lowerBound
                    } else {
                        contentEndIndex = cleanText.endIndex
                    }
                    
                    var content = String(cleanText[contentStartIndex..<contentEndIndex])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Cleanup punctuation residue
                    while content.first == ":" || content.first == "-" {
                        content.removeFirst()
                        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    if !content.isEmpty {
                        sections.append(AbstractSection(title: headerTitle, content: content))
                    }
                }
            }
        }
        
        return sections.isEmpty ? nil : sections
    }

    var cleanDescription: String {
        description.strippingHTMLTags()
    }
    
    var pubDate: String = ""
    var date: Date = Date() // Parsed date for sorting
    var creator: String = ""
    var journalName: String = "" // Added to track source in "All" view
    var imageURL: String? = nil // Added for abstract images
    var doi: String? {
        // Look for DOI in link or description
        let patterns = [
            "10\\.\\d{4,9}/[-._;()/:A-Z0-9]+", // Standard DOI regex
            "doi.org/(10\\.\\d{4,9}/[-._;()/:A-Z0-9]+)"
        ]
        
        for pattern in patterns {
            if let range = link.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return String(link[range]).replacingOccurrences(of: "doi.org/", with: "")
            }
            if let range = description.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return String(description[range]).replacingOccurrences(of: "doi.org/", with: "")
            }
        }
        return nil
    }

    // Helper for date parsing
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension String {
    func strippingHTMLTags() -> String {
        // First, handle common block tags for better structure
        var str = self.replacingOccurrences(of: "<(?i)p[^>]*>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)br[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)li[^>]*>", with: "\n• ", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)div[^>]*>", with: "\n", options: .regularExpression)
        
        // Strip all other tags
        str = str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode common HTML entities
        let entities = [
            "&quot;": "\"",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": "\"",
            "&ldquo;": "\"",
            "&ndash;": "-",
            "&mdash;": "—"
        ]
        
        for (entity, character) in entities {
            str = str.replacingOccurrences(of: entity, with: character)
        }
        
        // Clean up excessive whitespace
        return str
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

extension RSSItem {
    static func parseDate(_ dateString: String) -> Date {
        // Try standard RSS format
        if let date = RSSItem.dateFormatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        return Date.distantPast // Fallback
    }
}

class RSSService: NSObject, ObservableObject, XMLParserDelegate {
    @Published var items: [RSSItem] = []
    @Published var isFetching = false
    
    private var currentJournalName = ""
    private var cancellables = Set<AnyCancellable>()
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentCreator = ""
    private var currentImageURL: String? = nil
    private var tempItems: [RSSItem] = []
    
    func fetchFeed(url: URL, journalName: String) {
        currentJournalName = journalName
        isFetching = true
        items = []
        tempItems = []
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isFetching = false
                }
                return
            }
            
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            
            DispatchQueue.main.async {
                // Sort by date descending
                self.items = self.tempItems.sorted(by: { $0.date > $1.date })
                self.isFetching = false
            }
        }.resume()
    }
    
    func fetchAllFeeds(journals: [MedicalJournal]) {
        isFetching = true
        items = []
        tempItems = []
        
        // Concurrent fetch logic...
        let publishers = journals.map { journal -> AnyPublisher<(Data, String), Error> in
            var request = URLRequest(url: journal.rssURL)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .map { ($0.data, journal.name) }
                .catch { _ in Just((Data(), journal.name)) }
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .sink(receiveCompletion: { _ in
                DispatchQueue.main.async {
                    // Sort mixed feed by DATE
                    self.items = self.tempItems.sorted(by: { $0.date > $1.date })
                    self.isFetching = false
                }
            }, receiveValue: { results in
                for (data, name) in results {
                    let parser = XMLParser(data: data)
                    let subParser = SubFeedParser(journalName: name)
                    parser.delegate = subParser
                    parser.parse()
                    self.tempItems.append(contentsOf: subParser.items)
                }
            })
            .store(in: &cancellables)
    }
}

class SubFeedParser: NSObject, XMLParserDelegate {
    let journalName: String
    var items: [RSSItem] = []
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentCreator = ""
    private var currentImageURL: String? = nil
    
    init(journalName: String) {
        self.journalName = journalName
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if currentElement == "item" || currentElement == "entry" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            currentCreator = ""
            currentImageURL = nil
        }
        
        if currentElement == "link", let href = attributeDict["href"] {
            if currentLink.isEmpty || attributeDict["rel"] == "alternate" {
                currentLink = href
            }
        }
        
        if (currentElement == "media:content" || currentElement == "enclosure"), let url = attributeDict["url"] {
            if currentImageURL == nil {
                currentImageURL = url
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        switch currentElement {
        case "title": currentTitle += trimmed
        case "link": currentLink += trimmed
        case "description", "summary": currentDescription += trimmed
        case "pubDate", "published", "dc:date": currentPubDate += trimmed
        case "dc:creator": currentCreator += trimmed
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let item = RSSItem(
                title: currentTitle,
                link: currentLink,
                description: currentDescription,
                pubDate: currentPubDate,
                date: RSSItem.parseDate(currentPubDate),
                creator: currentCreator,
                journalName: journalName,
                imageURL: currentImageURL
            )
            items.append(item)
        }
    }
}

extension RSSService {
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if currentElement == "item" || currentElement == "entry" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            currentCreator = ""
            currentImageURL = nil
        }
        
        // Atom link parsing: <link href="...">
        if currentElement == "link", let href = attributeDict["href"] {
            // Only take the link if we don't have one yet, or if this is the "alternate" link
            if currentLink.isEmpty || attributeDict["rel"] == "alternate" {
                currentLink = href
            }
        }
        
        // Media RSS / Enclosure parsing: <media:content url="..."> or <enclosure url="...">
        if (currentElement == "media:content" || currentElement == "enclosure"), let url = attributeDict["url"] {
            if currentImageURL == nil {
                currentImageURL = url
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        switch currentElement {
        case "title": currentTitle += trimmed
        case "link": currentLink += trimmed
        case "description", "summary": currentDescription += trimmed
        case "pubDate", "published", "dc:date": currentPubDate += trimmed
        case "dc:creator": currentCreator += trimmed
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let item = RSSItem(
                title: currentTitle,
                link: currentLink,
                description: currentDescription,
                pubDate: currentPubDate,
                date: RSSItem.parseDate(currentPubDate),
                creator: currentCreator,
                journalName: currentJournalName,
                imageURL: currentImageURL
            )
            tempItems.append(item)
        }
    }
}
