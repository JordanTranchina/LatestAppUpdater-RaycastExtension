import Foundation

/// Possible installation progress update
struct CLIInstallProgress: Codable {
    let id: String
    let state: String
    let progress: Double?
    let message: String?
}

/// Manages app installations for the CLI with JSON streaming progress.
class CLIInstallManager {
    
    let appId: String
    let stream: Bool
    
    init(appId: String, stream: Bool) {
        self.appId = appId
        self.stream = stream
    }
    
    func install(completion: @escaping (Bool) -> Void) {
        // 1. Scan to find the app and its source
        let scanner = CLIAppScanner()
        scanner.scanApps { apps in
            guard let app = apps.first(where: { $0.id == self.appId }) else {
                self.reportError("App not found: \(self.appId)")
                completion(false)
                return
            }
            
            self.reportProgress(state: "initializing", message: "Preparing to install update for \(app.name)...")
            
            switch app.source.lowercased() {
            case "homebrew":
                self.installHomebrew(app: app, completion: completion)
            case "appstore":
                self.installAppStore(app: app, completion: completion)
            case "sparkle":
                self.installSparkle(app: app, completion: completion)
            default:
                self.reportError("Unsupported source for installation: \(app.source)")
                completion(false)
            }
        }
    }
    
    private func installHomebrew(app: CLIAppInfo, completion: @escaping (Bool) -> Void) {
        self.reportProgress(state: "installing", message: "Running brew upgrade for \(app.name)...")
        
        // We need the brew token. In some cases appId is the token, or we can look it up.
        // For now, let's assume appId works for brew info/upgrade if it was identified as homebrew.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew") // Default path
        if !FileManager.default.fileExists(atPath: process.executableURL!.path) {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew") // Apple Silicon path
        }
        
        process.arguments = ["upgrade", "--cask", app.id]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                // We could parse brew output for progress if needed
                self.reportProgress(state: "installing", message: output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        do {
            try process.run()
            process.terminationHandler = { process in
                fileHandle.readabilityHandler = nil
                if process.terminationStatus == 0 {
                    self.reportProgress(state: "completed", message: "Successfully updated \(app.name) via Homebrew.")
                    completion(true)
                } else {
                    self.reportError("Homebrew update failed for \(app.name) (exit code \(process.terminationStatus)).")
                    completion(false)
                }
            }
        } catch {
            self.reportError("Could not start Homebrew process: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func installAppStore(app: CLIAppInfo, completion: @escaping (Bool) -> Void) {
        self.reportProgress(state: "installing", message: "Requesting App Store update for \(app.name)...")
        
        // This will require the implementation that uses CommerceKit
        // For now, let's stub it with a message
        self.reportError("App Store installation via CLI is coming soon. Please use the App Store app for now.")
        completion(false)
    }
    
    private func installSparkle(app: CLIAppInfo, completion: @escaping (Bool) -> Void) {
        self.reportProgress(state: "installing", message: "Sparkle installation is not yet automated. Opening Appcast URL...")
        
        // Just report that we can't do it headlessly yet
        self.reportError("Sparkle headless installation is not yet implemented.")
        completion(false)
    }
    
    private func reportProgress(state: String, progress: Double? = nil, message: String? = nil) {
        if stream {
            let update = CLIInstallProgress(id: appId, state: state, progress: progress, message: message)
            if let data = try? JSONEncoder().encode(update), let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        } else if let message = message {
            print("[\(state.uppercased())] \(message)")
        }
    }
    
    private func reportError(_ message: String) {
        reportProgress(state: "error", message: message)
    }
}
