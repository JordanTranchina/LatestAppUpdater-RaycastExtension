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
        // Find the first <enclosure ... sparkle:version="..." ...>
        // Note: This is a very crude parser for MVP. 
        // Real logic should use XMLParser if available.
        
        let versionRegex = try? NSRegularExpression(pattern: "sparkle:version=\"([^\"]+)\"", options: [])
        let shortVersionRegex = try? NSRegularExpression(pattern: "sparkle:shortVersionString=\"([^\"]+)\"", options: [])
        
        let nsString = xmlString as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        var buildNumber: String?
        var versionNumber: String?
        
        if let match = versionRegex?.firstMatch(in: xmlString, options: [], range: range) {
            buildNumber = nsString.substring(with: match.range(at: 1))
        }
        
        if let match = shortVersionRegex?.firstMatch(in: xmlString, options: [], range: range) {
            versionNumber = nsString.substring(with: match.range(at: 1))
        }
        
        guard versionNumber != nil || buildNumber != nil else {
            self.finish(with: LatestError.updateInfoUnavailable)
            return
        }
        
        let version = Version(versionNumber: versionNumber, buildNumber: buildNumber)
        
        // For MVP, we don't parse changelogs or minimum OS versions yet
        self.update = App.Update(app: self.app, remoteVersion: version, minimumOSVersion: nil, source: .sparkle, date: nil, releaseNotes: nil, updateAction: .external(label: "Sparkle", block: { _ in }))
        
        self.finish()
    }
}
