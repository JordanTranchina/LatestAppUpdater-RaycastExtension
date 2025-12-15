//
//  CLIUpdateChecker.swift
//  latest-cli
//
//  Simplified update checker for CLI use.
//  Reuses the existing update check operations from Latest.
//

import Foundation

/// Simplified update checker for CLI that doesn't require AppKit.
class CLIUpdateChecker {
    
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 10
        return queue
    }()
    
    /// Check updates for the given bundles and call completion when done.
    func checkUpdates(for bundles: [App.Bundle], completion: @escaping ([CLIAppInfo]) -> Void) {
        var results = [CLIAppInfo]()
        let lock = NSLock()
        
        // Create a repository for caching
        let repository = UpdateRepository.newRepository()
        
        // Create operations for each bundle
        let operations = bundles.compactMap { bundle -> UpdateCheckerOperation? in
            return UpdateCheckCoordinator.operation(forChecking: bundle, repository: repository) { result in
                lock.lock()
                defer { lock.unlock() }
                
                let appInfo = CLIAppInfo(bundle: bundle, updateResult: result)
                results.append(appInfo)
            }
        }
        
        // If no operations, return immediately
        guard !operations.isEmpty else {
            completion([])
            return
        }
        
        // Run update checks in background
        DispatchQueue.global().async {
            self.operationQueue.addOperations(operations, waitUntilFinished: true)
            
            // Sort results by name
            let sorted = results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                completion(sorted)
            }
        }
    }
}
