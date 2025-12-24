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
    
    // For future use when we add update checking
    let availableVersion: String?
    let changelog: String?
    let canInstall: Bool
    
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
