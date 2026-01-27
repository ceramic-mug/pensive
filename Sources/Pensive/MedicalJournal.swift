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

struct RSSItem: Identifiable, Hashable {
    let id = UUID()
    var title: String = ""
    var link: String = ""
    var description: String = ""
    
    var cleanTitle: String {
        title.strippingHTMLTags()
    }
    
    var cleanDescription: String {
        description.strippingHTMLTags()
    }
    
    var pubDate: String = ""
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
}

extension String {
    func strippingHTMLTags() -> String {
        // First, handle some common block tags by replacing them with newlines to preserve some structure
        var str = self.replacingOccurrences(of: "<(?i)p[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)br[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)li[^>]*>", with: "\n• ", options: .regularExpression)
        
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
        
        // Clean up multiple newlines and spaces
        return str.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
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
                self.items = self.tempItems
                self.isFetching = false
            }
        }.resume()
    }
    
    func fetchAllFeeds(journals: [MedicalJournal]) {
        isFetching = true
        items = []
        tempItems = []
        
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
                    self.items = self.tempItems.sorted(by: { $0.pubDate > $1.pubDate })
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
                creator: currentCreator,
                journalName: currentJournalName,
                imageURL: currentImageURL
            )
            tempItems.append(item)
        }
    }
}
