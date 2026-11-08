//
//  PhotoTimeline.swift
//  Grow Companion
//
//  The grower's own photos in date order, with the stage each plant was in when
//  the photo was taken. Nothing here analyses an image.
//

import Foundation
import SwiftData

struct PlantPhoto: Identifiable {
    let id: String
    let entry: JournalEntry
    let date: Date?
    let stage: PlantStage?
    let fileName: String

    var dateLabel: String {
        guard let date else { return "Date not recorded" }
        return Format.shortDate(date)
    }

    var stageLabel: String {
        stage?.title ?? "Stage not recorded"
    }

    var plantName: String? { entry.plant?.displayName }
    var roomName: String? { entry.room?.name ?? entry.plant?.room?.name }
}

enum PhotoTimelineService {
    /// Entries that carry a photo, oldest first, with the plant's stage at the
    /// photo's date. A photo with no linked plant, or taken before the first
    /// recorded stage, says so instead of guessing.
    static func photos(
        from entries: [JournalEntry],
        plant: Plant? = nil
    ) -> [PlantPhoto] {
        let photos = entries.compactMap { entry -> PlantPhoto? in
            guard let fileName = entry.photoFileName, !fileName.isEmpty else { return nil }

            let linkedPlant = entry.plant ?? plant
            let photoStage: PlantStage?
            if let linkedPlant {
                photoStage = stage(of: linkedPlant, at: entry.createdAt)
            } else {
                photoStage = nil
            }

            return PlantPhoto(
                id: String(describing: entry.persistentModelID),
                entry: entry,
                date: entry.createdAt,
                stage: photoStage,
                fileName: fileName
            )
        }

        return photos.sorted { lhs, rhs in
            let left = lhs.date ?? .distantPast
            let right = rhs.date ?? .distantPast
            if left != right { return left < right }
            return lhs.id < rhs.id
        }
    }

    /// The last stage event at or before the date. Nil when the history does not
    /// reach back that far, which the UI labels as "Stage not recorded".
    static func stage(of plant: Plant, at date: Date) -> PlantStage? {
        plant.sortedStageEvents.last { $0.date <= date }?.stage
    }
}
