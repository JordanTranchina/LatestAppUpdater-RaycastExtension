//
//  CLIAppInfo.swift
//  latest-cli
//
//  JSON-serializable app information for CLI output.
//

import Foundation

/// JSON-serializable representation of app info.
struct CLIAppInfo: Codable {
    let id: String
    let name: String
    let installedVersion: String
    let source: String
    
    let availableVersion: String?
    let changelog: String?
    let canInstall: Bool
    let appStoreIdentifier: UInt64?
    let downloadURL: String?
    
    /// Initialize from an App.Bundle (without update info)
    init(bundle: App.Bundle) {
        self.id = bundle.bundleIdentifier
        self.name = bundle.name
        self.installedVersion = bundle.version.displayVersion
        self.source = bundle.source.rawValue
        
        // No update info available in simplified mode
        self.availableVersion = nil
        self.changelog = nil
        self.canInstall = false
        self.appStoreIdentifier = nil
        self.downloadURL = nil
    }

    /// Initialize from an App.Update
    init(update: App.Update) {
        self.id = update.app.bundleIdentifier
        self.name = update.app.name
        self.installedVersion = update.app.version.displayVersion
        self.source = update.source.rawValue
        self.availableVersion = update.remoteVersion.displayVersion
        self.changelog = update.releaseNotes?.displayString
        // For MVP, we consider an app "installable" if it has a remote version
        self.canInstall = true
        self.appStoreIdentifier = update.appStoreIdentifier
        self.downloadURL = update.downloadURL?.absoluteString
    }
}

extension App.Update.ReleaseNotes {
    var displayString: String {
        switch self {
        case .html(let string): return string
        case .url(let url): return url.absoluteString
        case .encoded(let data): return String(data: data, encoding: .utf8) ?? ""
        }
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
