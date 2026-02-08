import Foundation

extension URL {
    func proxied(using settings: AppSettings) -> URL {
        guard settings.useInstitutionalProxy, !settings.proxyRoot.isEmpty else {
            return self
        }
        
        switch settings.proxyType {
        case .prefix:
            let prefix = settings.proxyRoot
            let absoluteString = self.absoluteString
            
            // If the prefix already includes the URL, don't double up
            if absoluteString.contains(prefix) {
                return self
            }
            
            if let proxiedURL = URL(string: prefix + absoluteString) {
                return proxiedURL
            }
            
        case .domainReplacement:
            guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
                  let host = components.host else {
                return self
            }
            
            // Replace dots with dashes in the host
            let dashedHost = host.replacingOccurrences(of: ".", with: "-")
            
            // Append the proxy root
            components.host = "\(dashedHost).\(settings.proxyRoot)"
            
            if let proxiedURL = components.url {
                return proxiedURL
            }
        }
        
        return self
    }
}
