import Foundation
import SwiftUI

struct Passage: Identifiable {
    let id = UUID()
    let reference: String
    let text: String
}

class ScriptureService: ObservableObject {
    @Published var fetchedPassages: [Passage] = []
    @Published var scriptureText: String = "" // Keep for backward compatibility or simple view
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    func fetchScripture(passages: [String], apiKey: String) {
        guard !apiKey.isEmpty else {
            self.scriptureText = "Please enter your ESV API Key in Settings."
            return
        }
        
        isLoading = true
        error = nil
        
        let query = passages.joined(separator: ";")
        var components = URLComponents(string: "https://api.esv.org/v3/passage/text/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "include-passage-references", value: "false"),
            URLQueryItem(name: "include-verse-numbers", value: "false"),
            URLQueryItem(name: "include-first-verse-numbers", value: "false"),
            URLQueryItem(name: "include-footnotes", value: "false"),
            URLQueryItem(name: "include-headings", value: "false"),
            URLQueryItem(name: "include-short-copyright", value: "false"),
            URLQueryItem(name: "include-copyright", value: "false"),
            URLQueryItem(name: "indent-using", value: "space"),
            URLQueryItem(name: "horizontal-line-length", value: "0")
        ]
        
        var request = URLRequest(url: components.url!)
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let fetchedText = json["passages"] as? [String] {
                        
                        var result: [Passage] = []
                        for (index, text) in fetchedText.enumerated() {
                            if index < passages.count {
                                // Remove indentation: Replace standard 2-space indent with empty string
                                let processedText = text.replacingOccurrences(of: "  ", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                result.append(Passage(reference: passages[index].trimmingCharacters(in: .whitespacesAndNewlines), text: processedText))
                            }
                        }
                        self.fetchedPassages = result
                        self.scriptureText = fetchedText.joined(separator: "\n\n")
                    }
                } catch {
                    self.error = error
                    print("Decode error: \(error)")
                }
            }
        }.resume()
    }
}
