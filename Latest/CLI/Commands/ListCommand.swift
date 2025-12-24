//
//  ListCommand.swift
//  latest-cli
//
//  Lists all installed apps.
//

import Foundation

/// Command to list all installed apps.
class ListCommand {
    
    func execute(json: Bool) {
        let scanner = CLIAppScanner()
        
        scanner.scanApps { apps in
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
        print("Installed Apps (\(apps.count) found):")
        print("")
        for app in apps {
            print("  \(app.name)")
            print("    Version: \(app.installedVersion)")
            print("    Source: \(app.source)")
            print("    ID: \(app.id)")
            print("")
        }
        print("--------------------------")
        print("SCAN COMPLETED: \(apps.count) apps listed.")
        print("--------------------------")
    }
}
