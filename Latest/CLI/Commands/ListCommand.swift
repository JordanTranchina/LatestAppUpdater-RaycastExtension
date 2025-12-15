//
//  ListCommand.swift
//  latest-cli
//
//  Lists all apps and their update status.
//

import Foundation

/// Command to list all apps with their update status.
class ListCommand {
    
    func execute(json: Bool) {
        // Collect app bundles from /Applications
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let bundles = BundleCollector.collectBundles(at: applicationsURL)
        
        // Also check user Applications folder
        let userAppsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        let userBundles = BundleCollector.collectBundles(at: userAppsURL)
        
        let allBundles = bundles + userBundles
        
        // Check for updates for each bundle
        let checker = CLIUpdateChecker()
        
        checker.checkUpdates(for: allBundles) { apps in
            if json {
                self.outputJSON(apps: apps)
            } else {
                self.outputText(apps: apps)
            }
            exit(0)
        }
    }
    
    private func outputJSON(apps: [CLIAppInfo]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(apps)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            FileHandle.standardError.write("Error encoding JSON: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    
    private func outputText(apps: [CLIAppInfo]) {
        let updatable = apps.filter { $0.availableVersion != nil }
        
        if updatable.isEmpty {
            print("All apps are up to date!")
        } else {
            print("Apps with updates available:")
            print("")
            for app in updatable {
                print("  \(app.name)")
                print("    Current: \(app.installedVersion)")
                print("    Available: \(app.availableVersion ?? "N/A")")
                print("    Source: \(app.source)")
                print("")
            }
        }
    }
}
