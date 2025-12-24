//
//  InstallCommand.swift
//  latest-cli
//

import Foundation

class InstallCommand {
    func execute(appId: String?, stream: Bool) {
        if let appId = appId {
            print("Install requested for: \(appId)")
            print("Note: Installation via CLI is not yet implemented in this preview.")
        } else {
            print("Error: --id <bundle-id> is required for the install command.")
        }
        exit(1)
    }
}
