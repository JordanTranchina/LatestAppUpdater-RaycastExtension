//
//  CheckCommand.swift
//  latest-cli
//

import Foundation

class CheckCommand {
    func execute(json: Bool) {
        // For MVP, check just lists apps
        ListCommand().execute(json: json)
    }
}
