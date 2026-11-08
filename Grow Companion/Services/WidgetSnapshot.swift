//
//  WidgetSnapshot.swift
//  Grow Companion
//
//  The small summary the Home Screen and Lock Screen widget reads. It holds
//  counts by default and task names only when the grower turns them on, so a
//  locked phone never shows a plant, room or product name by accident.
//

import Foundation

struct WidgetCareSnapshot: Codable, Equatable {
    var generatedAt: Date
    var dueToday: Int
    var overdue: Int
    /// Empty unless the grower allowed task names.
    var titles: [String]
    /// Written by the app so the widget shows the app's language, plurals and
    /// all. Optional so a snapshot from an older build still decodes.
    var headline: String?
    var overdueText: String?
}

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.organizationName.Grow-Companion.shared"
    static let fileName = "care-snapshot.json"

    static func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    static func write(_ snapshot: WidgetCareSnapshot) {
        guard let url = fileURL() else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            // A widget is a convenience: a failed write leaves the last good
            // snapshot in place and never touches the store.
        }
    }

    static func clear() {
        guard let url = fileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func read() -> WidgetCareSnapshot? {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetCareSnapshot.self, from: data)
    }
}

enum WidgetSnapshotService {
    static var showsTaskTitles: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.widgetShowsTaskTitles) as? Bool ?? false
    }

    /// Counts always; titles only when the grower allows them.
    static func build(
        reminders: [CareReminder],
        now: Date = Date(),
        showsTitles: Bool
    ) -> WidgetCareSnapshot {
        let calendar = Calendar.current
        let enabled = reminders.filter { $0.isEnabled }
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        let dueToday = enabled
            .filter { $0.nextDueDate >= startOfToday && $0.nextDueDate < endOfToday }
            .count

        let overdue = enabled.filter { $0.nextDueDate < startOfToday }.count

        var titles: [String] = []
        if showsTitles {
            titles = Array(
                enabled
                    .filter { $0.nextDueDate < endOfToday }
                    .sorted { $0.nextDueDate < $1.nextDueDate }
                    .prefix(3)
                    .map(\.displayTitle)
            )
        }

        return WidgetCareSnapshot(
            generatedAt: Date(),
            dueToday: dueToday,
            overdue: overdue,
            titles: titles,
            headline: headline(dueToday: dueToday, overdue: overdue),
            overdueText: overdue > 0 ? String(localized: "\(overdue) overdue") : nil
        )
    }

    /// The widget renders this verbatim, so the plural and the language come
    /// from the app's catalog rather than the extension's.
    static func headline(dueToday: Int, overdue: Int) -> String {
        let total = dueToday + overdue
        guard total > 0 else { return String(localized: "No care tasks today") }
        return String(localized: "\(total) care task\(total == 1 ? "" : "s") today")
    }

    /// Rewrites the shared file from the current reminders and preference.
    static func refresh(reminders: [CareReminder], now: Date = Date()) {
        WidgetSnapshotStore.write(
            build(reminders: reminders, now: now, showsTitles: showsTaskTitles)
        )
    }
}
