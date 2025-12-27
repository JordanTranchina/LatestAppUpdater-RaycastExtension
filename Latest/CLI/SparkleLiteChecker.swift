import Foundation

/// A lightweight Sparkle Appcast parser for the CLI.
/// This avoids the heavy Sparkle framework dependency.
class SparkleLiteCheckerOperation: StatefulOperation, UpdateCheckerOperation, @unchecked Sendable {
    
    static var sourceType: App.Source {
        return .sparkle
    }
    
    private let app: App.Bundle
    private let url: URL?
    private var update: App.Update?
    
    static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
        guard let bundle = Bundle(path: url.path) else { return false }
        return Sparke.feedURL(from: bundle) != nil
    }
    
    required init(with bundle: App.Bundle, repository: UpdateRepository?, completionBlock: @escaping UpdateCheckerCompletionBlock) {
        self.app = bundle
        if let foundationBundle = Bundle(path: bundle.fileURL.path) {
            self.url = Sparke.feedURL(from: foundationBundle)
        } else {
            self.url = nil
        }
        
        super.init()
        
        self.completionBlock = {
            if let update = self.update {
                completionBlock(.success(update))
            } else {
                completionBlock(.failure(self.error ?? LatestError.updateInfoUnavailable))
            }
        }
    }
    
    override func execute() {
        guard let url = url else {
            self.finish(with: LatestError.updateInfoUnavailable)
            return
        }
        
        // Fetch the appcast XML
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.finish(with: error)
                return
            }
            
            guard let data = data else {
                self.finish(with: LatestError.updateInfoUnavailable)
                return
            }
            
            // Simple string-based parsing for MVP
            // Sparkle appcasts are XML and usually have items with sparkles enclosures
            if let xmlString = String(data: data, encoding: .utf8) {
                self.parse(xmlString: xmlString)
            } else {
                self.finish(with: LatestError.updateInfoUnavailable)
            }
        }
        task.resume()
    }
    
    private func parse(xmlString: String) {
        // Crudely split by <item> tags
        let items = xmlString.components(separatedBy: "<item>")
        var bestUpdate: App.Update?
        
        for item in items {
            let nsString = item as NSString
            let range = NSRange(location: 0, length: nsString.length)
            
            let versionRegex = try? NSRegularExpression(pattern: "sparkle:version=\"([^\"]+)\"", options: [])
            let shortVersionRegex = try? NSRegularExpression(pattern: "sparkle:shortVersionString=\"([^\"]+)\"", options: [])
            let urlRegex = try? NSRegularExpression(pattern: "url=\"([^\"]+)\"", options: [])
            
            var buildNumber: String?
            var versionNumber: String?
            var downloadURL: URL?
            
            if let match = versionRegex?.firstMatch(in: item, options: [], range: range) {
                buildNumber = nsString.substring(with: match.range(at: 1))
            }
            if let match = shortVersionRegex?.firstMatch(in: item, options: [], range: range) {
                versionNumber = nsString.substring(with: match.range(at: 1))
            }
            if let match = urlRegex?.firstMatch(in: item, options: [], range: range) {
                let urlString = nsString.substring(with: match.range(at: 1))
                downloadURL = URL(string: urlString)
            }
            
            if versionNumber != nil || buildNumber != nil {
                let foundVersion = Version(versionNumber: versionNumber, buildNumber: buildNumber)
                let foundUpdate = App.Update(app: self.app, remoteVersion: foundVersion, minimumOSVersion: nil, source: .sparkle, date: nil, releaseNotes: nil, updateAction: .external(label: "Sparkle", block: { _ in }), downloadURL: downloadURL)
                
                if bestUpdate == nil || bestUpdate!.remoteVersion < foundUpdate.remoteVersion {
                    bestUpdate = foundUpdate
                }
            }
        }
        
        guard let finalUpdate = bestUpdate else {
            self.finish(with: LatestError.updateInfoUnavailable)
            return
        }
        
        self.update = finalUpdate
        self.finish()
    }
}
