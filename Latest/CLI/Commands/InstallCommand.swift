//
//  InstallCommand.swift
//  latest-cli
//

import Foundation

class InstallCommand {
    func execute(appId: String?, stream: Bool) {
        guard let appId = appId else {
            print("Error: --id <bundle-id> is required for the install command.")
            exit(1)
        }
        
        let manager = CLIInstallManager(appId: appId, stream: stream)
        let semaphore = DispatchSemaphore(value: 0)
        
        manager.install { success in
            semaphore.signal()
        }
        
        semaphore.wait()
        exit(0)
    }
}
