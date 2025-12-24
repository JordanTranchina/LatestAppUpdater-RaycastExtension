//
//  CLIUpdateChecker.swift
//  latest-cli
//
//  Simplified app scanner for CLI use.
//  For MVP, just lists installed apps without full update checking.
//

import Foundation

/// Simplified app scanner for CLI that performs asynchronous update checks.
class CLIAppScanner {
    
    /// Scan for apps and check for updates.
    func scanApps(completion: @escaping ([CLIAppInfo]) -> Void) {
        DispatchQueue.global().async {
            // Collect app bundles from /Applications
            let applicationsURL = URL(fileURLWithPath: "/Applications")
            let bundles = BundleCollector.collectBundles(at: applicationsURL)
            
            // Also check user Applications folder
            let userAppsURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
            let userBundles = BundleCollector.collectBundles(at: userAppsURL)
            
            let allBundles = bundles + userBundles
            
            let group = DispatchGroup()
            var results = [CLIAppInfo]()
            let lock = NSLock()
            
            let repository = UpdateRepository.newRepository()
            
            for bundle in allBundles {
                group.enter()
                
                // Get the operation for this bundle
                if let op = UpdateCheckCoordinator.operation(forChecking: bundle, repository: repository, completion: { result in
                    lock.lock()
                    switch result {
                    case .success(let update):
                        results.append(CLIAppInfo(update: update))
                    case .failure:
                        // If check fails, still include the app as an "installed" entry
                        results.append(CLIAppInfo(bundle: bundle))
                    }
                    lock.unlock()
                    group.leave()
                }) {
                    // Execute the operation
                    op.execute()
                } else {
                    // No checker found for this app, just include as installed
                    lock.lock()
                    results.append(CLIAppInfo(bundle: bundle))
                    lock.unlock()
                    group.leave()
                }
            }
            
            // Wait for all checks to complete (with a 30s timeout)
            let _ = group.wait(timeout: .now() + 30)
            
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
