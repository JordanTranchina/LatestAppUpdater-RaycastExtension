//
//  CLIAppInfo.swift
//  latest-cli
//
//  JSON-serializable app information for CLI output.
//

import Foundation

/// JSON-serializable representation of app update info.
struct CLIAppInfo: Codable {
    let id: String
    let name: String
    let installedVersion: String
    let availableVersion: String?
    let source: String
    let changelog: String?
    let canInstall: Bool
    
    init(bundle: App.Bundle, updateResult: Result<App.Update, Error>?) {
        self.id = bundle.bundleIdentifier
        self.name = bundle.name
        self.installedVersion = bundle.version.displayVersion
        
        switch updateResult {
        case .success(let update):
            self.availableVersion = update.updateAvailable ? update.remoteVersion.displayVersion : nil
            self.changelog = update.releaseNotes?.plainText
            self.canInstall = update.updateAvailable
        case .failure, .none:
            self.availableVersion = nil
            self.changelog = nil
            self.canInstall = false
        }
        
        self.source = bundle.source.rawValue
    }
}

// MARK: - Version Extension

extension Version {
    /// Returns a display-friendly version string.
    var displayVersion: String {
        if let versionNumber = versionNumber {
            if let buildNumber = buildNumber, versionNumber != buildNumber {
                return "\(versionNumber) (\(buildNumber))"
            }
            return versionNumber
        }
        return buildNumber ?? "Unknown"
    }
}

// MARK: - ReleaseNotes Extension

extension App.Update.ReleaseNotes {
    /// Extracts plain text from release notes if possible.
    var plainText: String? {
        switch self {
        case .html(let string):
            // Strip HTML tags for CLI output
            return string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        case .encoded(let data):
            return String(data: data, encoding: .utf8)
        case .url:
            return nil
        }
    }
}
