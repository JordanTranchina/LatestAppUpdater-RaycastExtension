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
        // We typically have the appStoreIdentifier from the re-scan done in install()
        guard let appStoreId = app.appStoreIdentifier else {
            self.reportError("Could not determine App Store track ID for \(app.name).")
            completion(false)
            return
        }

        self.reportProgress(state: "installing", message: "Requesting App Store update for \(app.name) (ID: \(appStoreId))...")
        
        let operation = CLIMASUpdateOperation(bundleIdentifier: app.id, itemIdentifier: appStoreId) { state in
            switch state {
            case .initializing:
                self.reportProgress(state: "initializing", message: "Connecting to App Store...")
            case .downloading(let loaded, let total):
                let progress = total > 0 ? Double(loaded) / Double(total) : 0
                self.reportProgress(state: "downloading", progress: progress, message: "Downloading... (\(loaded/1024)KB / \(total/1024)KB)")
            case .extracting(let progress):
                self.reportProgress(state: "extracting", progress: progress, message: "Extracting...")
            case .installing:
                self.reportProgress(state: "installing", message: "Installing...")
            case .error(let error):
                self.reportError("App Store update failed: \(error.localizedDescription)")
                completion(false)
            case .none:
                self.reportProgress(state: "completed", message: "Successfully updated \(app.name) via App Store.")
                completion(true)
            default:
                break
            }
        }
        
        operation.start()
    }
    
    private func installSparkle(app: CLIAppInfo, completion: @escaping (Bool) -> Void) {
        guard let urlString = app.downloadURL, let url = URL(string: urlString) else {
            self.reportError("No download URL found for \(app.name).")
            completion(false)
            return
        }

        self.reportProgress(state: "downloading", progress: 0.1, message: "Downloading update from \(url.host ?? "Sparkle")...")
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                self.reportError("Download failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let localURL = localURL else {
                self.reportError("Download failed: no local URL.")
                completion(false)
                return
            }
            
            self.reportProgress(state: "extracting", progress: 0.5, message: "Extracting update...")
            
            // For MVP, handle .zip files via unzip command
            if url.pathExtension.lowercased() == "zip" {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-o", localURL.path, "-d", tempDir.path]
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        self.reportProgress(state: "installing", progress: 0.9, message: "Finishing installation...")
                        
                        // Find the .app in tempDir
                        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                        if let newAppURL = contents.first(where: { $0.pathExtension == "app" }) {
                            // Replace the old app
                            let oldAppURL = URL(fileURLWithPath: "/Applications/\(app.name).app")
                            
                            // Note: This might require permissions!
                            try? FileManager.default.removeItem(at: oldAppURL)
                            try FileManager.default.moveItem(at: newAppURL, to: oldAppURL)
                            
                            self.reportProgress(state: "completed", message: "Successfully updated \(app.name).")
                            completion(true)
                        } else {
                            self.reportError("Could not find .app in extracted archive.")
                            completion(false)
                        }
                    } else {
                        self.reportError("Unzip failed with exit code \(process.terminationStatus).")
                        completion(false)
                    }
                } catch {
                    self.reportError("Extraction failed: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                self.reportError("Unsupported archive format: .\(url.pathExtension). Only .zip is supported for headless Sparkle updates in this preview.")
                completion(false)
            }
        }
        task.resume()
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
