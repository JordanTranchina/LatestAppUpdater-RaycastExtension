//
//  main.swift
//  latest-cli
//
//  Command-line interface for Latest app update checking.
//  Used by Raycast extension to query updates without requiring Latest app to be open.
//

import Foundation

// MARK: - CLI Entry Point

let cli = LatestCLI()
cli.run()

// Keep the run loop alive for async operations
RunLoop.main.run()
