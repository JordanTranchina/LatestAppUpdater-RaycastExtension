//
//  StubOperations.swift
//  latest-cli
//
//  Stub classes to satisfy the compiler for the CLI target.
//  Since the CLI MVP doesn't perform actual update checks,
//  we can use these empty stubs instead of the real operations
//  which have heavy dependencies like Sparkle.
//

import Foundation

/// A base stub for update checker operations
class StubUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation, @unchecked Sendable {
    typealias UpdateCheckerCompletionBlock = ((Result<App.Update, Error>) -> Void)
    
    required init(with bundle: App.Bundle, repository: UpdateRepository?, completionBlock: @escaping (Result<App.Update, Error>) -> Void) {
        super.init()
        self.completionBlock = {
            completionBlock(.failure(LatestError.updateInfoUnavailable))
        }
    }
    
    static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
        return false
    }
    
    class var sourceType: App.Source {
        return .none
    }
    
    override func execute() {
        self.finish()
    }
}

class MacAppStoreUpdateCheckerOperation: StubUpdateCheckerOperation, @unchecked Sendable {
    override class var sourceType: App.Source { .appStore }
}

class SparkleUpdateCheckerOperation: StubUpdateCheckerOperation, @unchecked Sendable {
    override class var sourceType: App.Source { .sparkle }
}

class HomebrewCheckerOperation: StubUpdateCheckerOperation, @unchecked Sendable {
    override class var sourceType: App.Source { .homebrew }
}
