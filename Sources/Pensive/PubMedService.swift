import Foundation

// MARK: - Rate Limited Service
actor PubMedRateLimiter {
    private var lastRequestTime: Date = Date.distantPast
    private let minInterval: TimeInterval = 0.15 // ~6-7 requests per second to be safe (limit is 10/s)
    
    func wait() async {
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLast < minInterval {
            let sleepTime = UInt64((minInterval - timeSinceLast) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepTime)
        }
        
        lastRequestTime = Date()
    }
}

class PubMedService {
    static let shared = PubMedService()
    private let apiKey = "8903204de3f31ee6b98395a0ea710a48f408"
    private let baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
    private let rateLimiter = PubMedRateLimiter()
    
    private init() {}

    func fetchAbstract(doi: String) async throws -> String {
        print("DEBUG: PubMedService fetchAbstract called for DOI: \(doi)")
        // Enforce rate limit
        await rateLimiter.wait()
        
        // 1. Convert DOI to PMID
        // Note: The [Location+ID] tag works for DOIs in the term parameter
        guard let encodedDOI = doi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("DEBUG: Bad URL encoding for DOI: \(doi)")
            throw URLError(.badURL)
        }
        
        // Use history server if possible? No, standard esearch is fine but we should handle history for batching in future.
        // For now, one-off is fine with rate limiting.
        
        let searchPath = "\(baseURL)esearch.fcgi?db=pubmed&term=\(encodedDOI)[Location+ID]&retmode=json&api_key=\(apiKey)"
        guard let searchURL = URL(string: searchPath) else { throw URLError(.badURL) }
        
        print("DEBUG: Searching PubMed: \(searchURL)")
        let (searchData, _) = try await URLSession.shared.data(from: searchURL)
        
        // Debug print
        // if let jsonStr = String(data: searchData, encoding: .utf8) { print("Search response: \(jsonStr)") }
        
        let searchResult = try JSONDecoder().decode(PubMedSearchResponse.self, from: searchData)
        
        guard let pmid = searchResult.esearchresult.idlist.first else {
            print("DEBUG: No PMID found for DOI: \(doi)")
            throw PubMedError.noPMIDFound
        }
        
        print("DEBUG: Found PMID: \(pmid). Fetching abstract...")
        
        // Enforce rate limit again for the second call
        await rateLimiter.wait()
        
        // 2. Fetch XML for the PMID
        let fetchPath = "\(baseURL)efetch.fcgi?db=pubmed&id=\(pmid)&retmode=xml&api_key=\(apiKey)"
        guard let fetchURL = URL(string: fetchPath) else { throw URLError(.badURL) }
        
        let (xmlData, _) = try await URLSession.shared.data(from: fetchURL)
        
        print("DEBUG: Abstract fetched successfully for \(doi)")
        
        // 3. Parse XML
        let parser = PubMedXMLParser(data: xmlData)
        return parser.parse()
    }
}

enum PubMedError: Error {
    case noPMIDFound
}

// MARK: - JSON Helpers
struct PubMedSearchResponse: Codable {
    struct SearchResult: Codable {
        let idlist: [String]
    }
    let esearchresult: SearchResult
}

// MARK: - XML Parser Delegate
class PubMedXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var currentElement = ""
    private var abstractText = ""
    private var isInsideAbstract = false
    
    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }
    
    func parse() -> String {
        parser.parse()
        return abstractText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "AbstractText" {
            isInsideAbstract = true
             // Sometimes AbstractText has attributes like Label="BACKGROUND" which are very useful!
             // We can check for that to format better.
             if let label = attributeDict["Label"] {
                 abstractText += "\(label): "
             }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideAbstract {
            abstractText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "AbstractText" {
            isInsideAbstract = false
            abstractText += "\n\n" // Add newlines between structured sections from XML
        }
    }
}
