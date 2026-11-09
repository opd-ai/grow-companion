//
//  EducationProgress.swift
//  Grow Companion
//
//  Which lessons the grower has read, and when. Local only: two preferences
//  inside SettingsKey.all, so delete-all clears them with everything else.
//  The store is a value with one loader, so the reading progress can be tested
//  without a view.
//

import Foundation

struct EducationReadingProgress: Equatable {
    var completed: Set<String> = []
    var readAt: [String: Date] = [:]

    static let empty = EducationReadingProgress()

    func isRead(_ id: String) -> Bool { completed.contains(id) }

    /// When the grower marked a lesson read, when that was recorded.
    func date(for id: String) -> Date? { readAt[id] }

    func count(in lessons: [EducationLesson]) -> Int {
        lessons.reduce(0) { total, lesson in
            total + (completed.contains(lesson.id) ? 1 : 0)
        }
    }

    func allRead(in lessons: [EducationLesson]) -> Bool {
        !lessons.isEmpty && count(in: lessons) == lessons.count
    }
}

enum EducationProgressStore {
    static func load(from defaults: UserDefaults = .standard) -> EducationReadingProgress {
        EducationReadingProgress(
            completed: Set(defaults.stringArray(forKey: SettingsKey.educationCompletedLessons) ?? []),
            readAt: readDates(from: defaults)
        )
    }

    /// Records a lesson as read at a time, and returns the updated progress so
    /// the caller never has to re-read the store.
    @discardableResult
    static func markRead(
        _ id: String,
        at date: Date = Date(),
        in defaults: UserDefaults = .standard
    ) -> EducationReadingProgress {
        var progress = load(from: defaults)
        progress.completed.insert(id)
        progress.readAt[id] = date
        write(progress, to: defaults)
        return progress
    }

    /// Clears the read state and its date. The lesson stays in the library.
    @discardableResult
    static func markUnread(
        _ id: String,
        in defaults: UserDefaults = .standard
    ) -> EducationReadingProgress {
        var progress = load(from: defaults)
        progress.completed.remove(id)
        progress.readAt[id] = nil
        write(progress, to: defaults)
        return progress
    }

    private static func readDates(from defaults: UserDefaults) -> [String: Date] {
        guard let stored = defaults.dictionary(forKey: SettingsKey.educationLessonReadAt) else {
            return [:]
        }
        var dates: [String: Date] = [:]
        for (id, value) in stored {
            guard let seconds = value as? Double else { continue }
            dates[id] = Date(timeIntervalSince1970: seconds)
        }
        return dates
    }

    private static func write(_ progress: EducationReadingProgress, to defaults: UserDefaults) {
        defaults.set(progress.completed.sorted(), forKey: SettingsKey.educationCompletedLessons)

        // Only the dates of lessons that are still read are kept, so an unread
        // lesson leaves no trace in the preferences.
        var stored: [String: Double] = [:]
        for (id, date) in progress.readAt where progress.completed.contains(id) {
            stored[id] = date.timeIntervalSince1970
        }

        if stored.isEmpty {
            defaults.removeObject(forKey: SettingsKey.educationLessonReadAt)
        } else {
            defaults.set(stored, forKey: SettingsKey.educationLessonReadAt)
        }
    }
}
