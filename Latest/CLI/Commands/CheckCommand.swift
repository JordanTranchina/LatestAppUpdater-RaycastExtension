//
//  CheckCommand.swift
//  latest-cli
//
//  Forces a fresh check for updates.
//

import Foundation

/// Command to force a fresh update check.
class CheckCommand {
    
    func execute(json: Bool) {
        // This is functionally the same as list, but we might add
        // cache-busting or force-refresh logic here later
        ListCommand().execute(json: json)
    }
}
