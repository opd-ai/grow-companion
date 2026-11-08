//
//  LogWateringIntent.swift
//  Grow Companion
//
//  The Siri and Shortcuts surface of story 3. Everything it needs is decided
//  in `WateringShortcutService`; this file only opens the store and speaks the
//  result.
//

import AppIntents
import Foundation
import SwiftData

struct LogWateringIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a watering"

    @Parameter(title: "Room")
    var roomName: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log a watering in \(\.$roomName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let requested = roomName
        let message = try await MainActor.run { () throws -> String in
            let boot = StoreBoot()
            guard let container = boot.container else {
                throw WateringShortcutError.storeUnavailable
            }
            let outcome = try WateringShortcutService.logWatering(
                requestedRoom: requested,
                in: ModelContext(container)
            )
            return String(localized: "Logged a watering in \(outcome.roomName).")
        }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct GrowCompanionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWateringIntent(),
            phrases: ["Log a watering in \(.applicationName)"],
            shortTitle: "Log a watering",
            systemImageName: "drop"
        )
    }
}
