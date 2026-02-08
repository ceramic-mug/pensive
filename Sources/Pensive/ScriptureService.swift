import SwiftUI
import Combine

struct Passage: Identifiable {
    let id = UUID()
    let reference: String
    let text: String
    let isPoetic: Bool
    
    func text(isCompact: Bool) -> String {
        if isPoetic && isCompact {
            // Protect double newlines (stanzas) with a unique placeholder that has no newlines
            let placeholder = "[[STANZABREAK]]"
            return text
                .replacingOccurrences(of: "\n\n", with: placeholder)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: placeholder, with: "\n\n")
                .replacingOccurrences(of: "\t", with: "")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
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
                                let ref = passages[index].trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Detect if it's a poetic book or has poetic formatting
                                let poeticBooks = ["Psalms", "Job", "Proverbs", "Ecclesiastes", "Song of Solomon"]
                                var isPoetic = poeticBooks.contains { ref.contains($0) }
                                
                                // Even if not a poetic book, check if the content looks poetic (lots of leading spaces)
                                if !isPoetic && text.contains("\n    ") {
                                    isPoetic = true
                                }
                                
                                var processedText = text
                                
                                // Fix the "extra newline" by replacing triple newlines with double
                                processedText = processedText.replacingOccurrences(of: "\n\n\n", with: "\n\n")
                                
                                if isPoetic {
                                    // Normalize indents
                                    processedText = processedText.components(separatedBy: .newlines)
                                        .map { line in
                                            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                                            if line.hasPrefix("    ") {
                                                return "\t" + trimmedLine
                                            } else if line.hasPrefix("  ") {
                                                return "  " + trimmedLine
                                            }
                                            return trimmedLine
                                        }
                                        .joined(separator: "\n")
                                } else {
                                    // Normal prose
                                    // Protect double newlines from being accidentally collapsed during single-newline stripping
                                    processedText = processedText.components(separatedBy: "\n\n")
                                        .map { paragraph in
                                            return paragraph.replacingOccurrences(of: "\n", with: " ")
                                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                        }
                                        .joined(separator: "\n\n")
                                }
                                
                                processedText = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
                                result.append(Passage(reference: ref, text: processedText, isPoetic: isPoetic))
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
