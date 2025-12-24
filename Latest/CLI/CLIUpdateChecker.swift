//
//  CLIUpdateChecker.swift
//  latest-cli
//
//  Simplified app scanner for CLI use.
//  For MVP, just lists installed apps without full update checking.
//

import Foundation

/// Simplified app scanner for CLI that doesn't require AppKit or Sparkle.
class CLIAppScanner {
    
    /// Scan for apps and return their info.
    func scanApps(completion: @escaping ([CLIAppInfo]) -> Void) {
        DispatchQueue.global().async {
            var results = [CLIAppInfo]()
            
            // Collect app bundles from /Applications
            let applicationsURL = URL(fileURLWithPath: "/Applications")
            let bundles = BundleCollector.collectBundles(at: applicationsURL)
            
            // Also check user Applications folder
            let userAppsURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
            let userBundles = BundleCollector.collectBundles(at: userAppsURL)
            
            let allBundles = bundles + userBundles
            
            // Convert to CLI info objects
            for bundle in allBundles {
                let info = CLIAppInfo(bundle: bundle)
                results.append(info)
            }
            
            // Sort by name
            let sorted = results.sorted { 
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending 
            }
            
            DispatchQueue.main.async {
                completion(sorted)
            }
        }
    }
}
