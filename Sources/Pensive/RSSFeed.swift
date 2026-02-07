import Foundation
import SwiftData
import SwiftUI
import Combine

@Model
final class RSSFeed: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var urlString: String = ""
    var category: String = "General"
    
    var rssURL: URL? {
        URL(string: urlString)
    }
    
    init(name: String, urlString: String, category: String = "General") {
        self.name = name
        self.urlString = urlString
        self.category = category
    }
    
    static let defaults: [RSSFeed] = [
        RSSFeed(name: "NEJM", urlString: "https://www.nejm.org/action/showFeed?jc=nejm&type=etoc&feed=rss", category: "Medical"),
        RSSFeed(name: "The Lancet", urlString: "https://www.thelancet.com/rssfeed/lancet_current.xml", category: "Medical"),
        RSSFeed(name: "AAP Pediatrics", urlString: "https://publications.aap.org/rss/site_1000005/1000005.xml", category: "Medical"),
        RSSFeed(name: "Annals of Internal Medicine", urlString: "https://www.acpjournals.org/action/showFeed?type=etoc&feed=rss&jc=aim", category: "Medical")
    ]
}

@Model
final class ReadArticle: Identifiable {
    var id: UUID = UUID()
    var url: String = ""
    var title: String = ""
    var category: String = ""
    var publicationName: String = ""
    var dateRead: Date = Date()
    var isFlagged: Bool = false
    
    init(url: String, title: String, category: String, publicationName: String, isFlagged: Bool = false) {
        self.url = url
        self.title = title
        self.category = category
        self.publicationName = publicationName
        self.isFlagged = isFlagged
        self.dateRead = Date()
    }
}

struct RSSItem: Identifiable, Hashable {
    let id = UUID()
    var title: String = ""
    var link: String = ""
    var description: String = ""
    var pubDate: String = ""
    var date: Date = Date()
    var creator: String = ""
    var journalName: String = ""
    var imageURL: String? = nil
    
    var cleanTitle: String {
        title.strippingHTMLTags()
    }
    
    var cleanDescription: String {
        description.strippingHTMLTags()
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static func parseDate(_ dateString: String) -> Date {
        if let date = RSSItem.dateFormatter.date(from: dateString) {
            return date
        }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        return Date.distantPast
    }
}

extension String {
    func strippingHTMLTags() -> String {
        var str = self.replacingOccurrences(of: "<(?i)p[^>]*>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)br[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<(?i)li[^>]*>", with: "\n• ", options: .regularExpression)
        
        str = str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        let entities = ["&quot;": "\"", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&rsquo;": "'", "&lsquo;": "'", "&rdquo;": "\"", "&ldquo;": "\"", "&ndash;": "-", "&mdash;": "—"]
        for (entity, character) in entities {
            str = str.replacingOccurrences(of: entity, with: character)
        }
        
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
class RSSService: ObservableObject {
    @Published var items: [RSSItem] = []
    @Published var isFetching = false
    private var cancellables = Set<AnyCancellable>()
    private var tempItems: [RSSItem] = []
    
    func shuffleItems() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            items.shuffle()
        }
    }
    
    func shuffleItemsImmediate() {
        items.shuffle()
    }
    
    func fetchFeed(url: URL, journalName: String) {
        isFetching = true
        items = []
        tempItems = []
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async { self.isFetching = false }
                return
            }
            
            DispatchQueue.main.async {
                let parser = XMLParser(data: data)
                let subParser = SubFeedParser(journalName: journalName)
                parser.delegate = subParser
                parser.parse()
                self.items = subParser.items.sorted(by: { $0.date > $1.date })
                self.isFetching = false
            }
        }.resume()
    }
    
    func fetchAllFeeds(feeds: [RSSFeed]) {
        isFetching = true
        items = []
        tempItems = []
        
        let publishers = feeds.compactMap { feed -> AnyPublisher<(Data, String), Error>? in
            guard let url = feed.rssURL else { return nil }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .map { ($0.data, feed.name) }
                .catch { _ in Just((Data(), feed.name)) }
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                self.items = self.tempItems.sorted(by: { $0.date > $1.date })
                self.isFetching = false
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

final class SubFeedParser: NSObject, XMLParserDelegate {
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
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description", "summary": currentDescription += string
        case "pubDate", "published", "dc:date": currentPubDate += string
        case "dc:creator": currentCreator += string
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let item = RSSItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                date: RSSItem.parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)),
                creator: currentCreator.trimmingCharacters(in: .whitespacesAndNewlines),
                journalName: journalName,
                imageURL: currentImageURL
            )
            items.append(item)
        }
    }
}
