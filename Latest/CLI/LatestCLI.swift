//
//  LatestCLI.swift
//  latest-cli
//
//  Main CLI command dispatcher.
//

import Foundation

/// Main CLI class that parses arguments and dispatches to appropriate commands.
class LatestCLI {
    
    enum Command: String {
        case list
        case check
        case install
        case help
    }
    
    func run() {
        let arguments = CommandLine.arguments
        
        // Default to help if no arguments
        guard arguments.count > 1 else {
            printHelp()
            exit(0)
        }
        
        let commandString = arguments[1]
        
        // Check for --json flag
        let useJSON = arguments.contains("--json")
        
        guard let command = Command(rawValue: commandString) else {
            printError("Unknown command: \(commandString)")
            printHelp()
            exit(1)
        }
        
        switch command {
        case .list:
            ListCommand().execute(json: useJSON)
        case .check:
            CheckCommand().execute(json: useJSON)
        case .install:
            let appId = extractArgument("--id", from: arguments)
            let stream = arguments.contains("--json-stream")
            InstallCommand().execute(appId: appId, stream: stream)
        case .help:
            printHelp()
            exit(0)
        }
    }
    
    private func extractArgument(_ flag: String, from arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
    
    private func printHelp() {
        let help = """
        latest-cli - Command-line interface for Latest app
        
        USAGE:
            latest-cli <command> [options]
        
        COMMANDS:
            list    List all apps and their update status
            check   Force a re-check for updates
            install Install an update for a specific app
            help    Show this help message
        
        OPTIONS:
            --json          Output in JSON format
            --json-stream   Stream JSON events (for install command)
            --id <app-id>   Bundle identifier of app to install
        
        EXAMPLES:
            latest-cli list --json
            latest-cli check --json
            latest-cli install --id com.example.app --json-stream
        """
        print(help)
    }
    
    private func printError(_ message: String) {
        FileHandle.standardError.write("Error: \(message)\n".data(using: .utf8)!)
    }
}
