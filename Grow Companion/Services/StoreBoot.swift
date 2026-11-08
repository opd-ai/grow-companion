//
//  StoreBoot.swift
//  Grow Companion
//
//  Opens the on-device store at launch. A store that cannot be opened is a
//  recovery state, never an empty grow: the app does not fall back to an
//  in-memory store that would look like the user's data had vanished.
//

import Foundation
import Observation
import SwiftData

enum StoreBootError: LocalizedError {
    case noApplicationDirectory
    case noStoreFile
    case stillUnreadable

    var errorDescription: String? {
        switch self {
        case .noApplicationDirectory:
            return "The app's storage folder could not be found."
        case .noStoreFile:
            return "The old store could not be moved aside."
        case .stillUnreadable:
            return "A new store could not be opened either. Restart the app and try again."
        }
    }
}

@Observable
final class StoreBoot {
    private(set) var container: ModelContainer?
    private(set) var failureMessage: String?

    /// The folder an unreadable store was moved into, when the grower started
    /// a new grow, so support can point at the copy that was kept.
    private(set) var archivedStoreName: String?

    init() {
        open()
    }

    /// Tries to open the store again. Leaves `container` nil on failure.
    func open() {
        DataProtection.prepare()

        let configuration = ModelConfiguration("GrowCompanion", schema: DataInventory.schema)

        do {
            container = try ModelContainer(for: DataInventory.schema, configurations: [configuration])
            failureMessage = nil
        } catch {
            container = nil
            failureMessage = error.localizedDescription
        }
    }

    /// Moves the unreadable store aside, keeping every byte, and opens a new
    /// empty store. The old copy is never overwritten or deleted.
    func startNewGrow() throws {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StoreBootError.noApplicationDirectory
        }

        let destination = base.appendingPathComponent("UnreadableStore-\(Self.stamp())", isDirectory: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)

        let items = (try? manager.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
        let storeItems = items.filter { $0.lastPathComponent.hasPrefix("GrowCompanion") }
        guard !storeItems.isEmpty else { throw StoreBootError.noStoreFile }

        for item in storeItems {
            try manager.moveItem(at: item, to: destination.appendingPathComponent(item.lastPathComponent))
        }

        archivedStoreName = destination.lastPathComponent
        open()

        if container == nil {
            throw StoreBootError.stillUnreadable
        }
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
