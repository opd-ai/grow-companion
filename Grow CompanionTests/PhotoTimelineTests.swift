//
//  PhotoTimelineTests.swift
//  Grow CompanionTests
//
//  Photos in date order, the stage at the photo's date, and deleting an entry
//  with its display file, thumbnail and cache entry.
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import Grow_Companion

@MainActor
struct PhotoTimelineTests {
    @Test func photosAreSortedAndCarryTheStageAtTheirDate() throws {
        let context = try makeContext()
        let plant = Plant(name: "One", stage: .flower)
        context.insert(plant)

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let vegEvent = StageEvent(stage: .veg, date: base, plant: plant)
        let flowerEvent = StageEvent(
            stage: .flower,
            date: base.addingTimeInterval(5 * 86_400),
            plant: plant
        )
        context.insert(vegEvent)
        context.insert(flowerEvent)

        let early = JournalEntry(
            kind: .photo,
            text: "Before the record",
            photoFileName: "early.jpg",
            createdAt: base.addingTimeInterval(-86_400),
            plant: plant
        )
        let middle = JournalEntry(
            kind: .photo,
            text: "Veg photo",
            photoFileName: "middle.jpg",
            createdAt: base.addingTimeInterval(3 * 86_400),
            plant: plant
        )
        let late = JournalEntry(
            kind: .photo,
            text: "Flower photo",
            photoFileName: "late.jpg",
            createdAt: base.addingTimeInterval(6 * 86_400),
            plant: plant
        )
        let textOnly = JournalEntry(kind: .note, text: "No photo", createdAt: base, plant: plant)
        context.insert(early)
        context.insert(middle)
        context.insert(late)
        context.insert(textOnly)
        try context.save()

        let photos = PhotoTimelineService.photos(
            from: [late, textOnly, early, middle]
        )

        #expect(photos.count == 3)
        #expect(photos.map(\.fileName) == ["early.jpg", "middle.jpg", "late.jpg"])
        #expect(photos[0].stageLabel == "Stage not recorded")
        #expect(photos[1].stage == .veg)
        #expect(photos[2].stage == .flower)
        #expect(photos[1].stageLabel == "Veg")
        #expect(photos.allSatisfy { $0.plantName == "One" })
    }

    @Test func aPhotoWithoutAPlantSaysStageNotRecorded() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        context.insert(room)
        let entry = JournalEntry(
            kind: .photo,
            text: "Room shot",
            photoFileName: "room.jpg",
            room: room
        )
        context.insert(entry)
        try context.save()

        let photo = try #require(PhotoTimelineService.photos(from: [entry]).first)
        #expect(photo.stage == nil)
        #expect(photo.stageLabel == "Stage not recorded")
        #expect(photo.roomName == "Tent")
        #expect(!photo.dateLabel.isEmpty)

        let undated = PlantPhoto(
            id: "undated",
            entry: entry,
            date: nil,
            stage: nil,
            fileName: "room.jpg"
        )
        #expect(undated.dateLabel == "Date not recorded")
        #expect(undated.stageLabel == "Stage not recorded")
    }

    @Test func deletingAnEntryRemovesThePhotoThumbnailAndCache() throws {
        let context = try makeContext()
        let imageData = try #require(testImageData())
        let fileName = try #require(PhotoStore.save(imageData: imageData))
        defer { PhotoStore.delete(named: fileName) }

        let entry = JournalEntry(
            kind: .photo,
            text: "Leaf",
            photoFileName: fileName,
            createdAt: Date()
        )
        context.insert(entry)
        try context.save()

        let displayURL = PhotoStore.url(for: fileName)
        let thumbnailURL = PhotoStore.url(for: PhotoStore.thumbnailName(for: fileName))
        #expect(FileManager.default.fileExists(atPath: displayURL.path))
        #expect(FileManager.default.fileExists(atPath: thumbnailURL.path))
        #expect(PhotoStore.thumbnail(named: fileName) != nil)

        try JournalEntryService.delete(entry, in: context)

        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: displayURL.path))
        #expect(!FileManager.default.fileExists(atPath: thumbnailURL.path))
        #expect(PhotoStore.thumbnail(named: fileName) == nil)
        #expect(PhotoStore.image(named: fileName) == nil)
        #expect(PhotoTimelineService.photos(from: []).isEmpty)
    }

    // MARK: Support

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func testImageData() -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemGreen.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
