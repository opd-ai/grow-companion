//
//  SharingTests.swift
//  Grow CompanionTests
//
//  Scoping, privacy and package tests for protected grow shares.
//

import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

private struct ShareFixture {
    let container: ModelContainer
    let source: SharePayloadBuilder.Source
    let room: Room
    let otherRoom: Room
    let plant: Plant
    let otherPlant: Plant
}

private func makeFixture() throws -> ShareFixture {
    let container = try ModelContainer(
        for: DataInventory.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    let context = ModelContext(container)

    let profile = GrowProfile(stateCode: "CA", stateName: "California", countyOrCity: "Secret County")
    context.insert(profile)

    let room = Room(name: "Tent A", canopySquareMeters: 1.5)
    context.insert(room)
    let otherRoom = Room(name: "Tent B", canopySquareMeters: 2.0)
    context.insert(otherRoom)

    let plant = Plant(name: "Alpha", stage: .flower, room: room)
    plant.dryWeightGrams = 40
    plant.wetWeightGrams = 120
    plant.harvestedAt = Date(timeIntervalSince1970: 1_700_000_000)
    plant.harvestDispositionRaw = HarvestDisposition.retained.rawValue
    plant.ratingRaw = 4
    context.insert(plant)

    let otherPlant = Plant(name: "Beta", stage: .veg, room: otherRoom)
    context.insert(otherPlant)

    context.insert(JournalEntry(text: "private journal secret", plant: plant))
    context.insert(EnvironmentReading(date: Date(timeIntervalSince1970: 1_700_001_000), temperatureC: 23, humidityPercent: 55, room: room))
    context.insert(FeedEvent(date: Date(timeIntervalSince1970: 1_700_002_000), kind: .water, volumeLiters: 1.2, room: room))
    context.insert(ScoutingCheck(date: Date(timeIntervalSince1970: 1_700_003_000), findings: [.pests], note: "checks", plant: plant))
    try context.save()

    let source = SharePayloadBuilder.Source(
        profile: profile,
        rooms: [room, otherRoom],
        plants: [plant, otherPlant],
        rule: RulePack.rule(forStateCode: "CA"),
        warningThreshold: 0.8
    )

    return ShareFixture(
        container: container,
        source: source,
        room: room,
        otherRoom: otherRoom,
        plant: plant,
        otherPlant: otherPlant
    )
}

private func scope(
    rooms: [String],
    plants: [String],
    categories: [ShareCategory],
    days: Int = 7
) -> ShareScope {
    ShareScope(
        rooms: rooms,
        plants: plants,
        categories: categories,
        expiresAt: Date().addingTimeInterval(TimeInterval(days) * 86_400)
    )
}

private func identity() -> SecureEnvelope.Identity {
    SecureEnvelope.Identity(
        agreement: Curve25519.KeyAgreement.PrivateKey(),
        signing: Curve25519.Signing.PrivateKey()
    )
}

struct SharePayloadTests {
    @Test func scopeSelectsOnlyTheChosenRecords() throws {
        let fixture = try makeFixture()
        let payload = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.plantRecords])
        )

        #expect(payload.rooms.map(\.name) == ["Tent A"])
        _ = fixture.otherRoom
        #expect(payload.plants.map(\.name) == ["Alpha"])
        #expect(payload.readings.isEmpty)
        #expect(payload.feedEvents.isEmpty)
        #expect(payload.treatments.isEmpty)
    }

    @Test func environmentCategoryCarriesReadings() throws {
        let fixture = try makeFixture()
        let payload = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: [], categories: [.environment])
        )

        #expect(payload.readings.count == 1)
        #expect(payload.readings.first?.temperatureC == 23)
    }

    @Test func careHistoryCarriesFeedsAndScouting() throws {
        let fixture = try makeFixture()
        let payload = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.careHistory])
        )

        #expect(payload.feedEvents.count == 1)
        #expect(payload.scoutingChecks.count == 1)
    }

    @Test func harvestIsOmittedUnlessSelected() throws {
        let fixture = try makeFixture()

        let plantOnly = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.plantRecords])
        )
        #expect(plantOnly.plants.first?.harvest == nil)

        let withHarvest = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.plantRecords, .harvest])
        )
        #expect(withHarvest.plants.first?.harvest?.dryWeightGrams == 40)
        #expect(withHarvest.plants.first?.harvest?.disposition == "Retained")
    }

    @Test func complianceIsOnlyComputedWhenSelected() throws {
        let fixture = try makeFixture()
        let withoutCompliance = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.plantRecords])
        )
        #expect(withoutCompliance.compliance == nil)

        let withCompliance = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.compliance])
        )
        #expect(withCompliance.compliance != nil)
        #expect(withCompliance.compliance?.countedPlants == 1)
        #expect(withCompliance.compliance?.jurisdictionCode == "US-CA")
    }

    @Test func payloadNeverCarriesJournalCountyOrPlantNotes() throws {
        let fixture = try makeFixture()
        fixture.plant.notes = "plant note secret"

        let payload = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: ShareCategory.allCases)
        )
        let json = String(decoding: try SharePackageService.encode(payload), as: UTF8.self)

        #expect(!json.contains("private journal secret"))
        #expect(!json.contains("Secret County"))
        #expect(!json.contains("plant note secret"))
    }

    @Test func expiredScopeIsPushedForward() throws {
        let fixture = try makeFixture()
        let past = Date().addingTimeInterval(-86_400)
        let payload = SharePayloadBuilder.build(
            source: fixture.source,
            scope: ShareScope(rooms: ["Tent A"], plants: [], categories: [.plantRecords], expiresAt: past)
        )

        #expect(payload.expiresAt > Date())
    }
}

struct SharePackageTests {
    @Test func shareCodeRoundTrips() throws {
        let keys = identity()
        let code = ShareCode.encode(keys)
        let decoded = try ShareCode.decode(code)

        #expect(SecureEnvelope.keyID(for: decoded.agreement) == SecureEnvelope.keyID(for: keys.agreementPublicKey))
        #expect(SecureEnvelope.keyID(for: decoded.signing) == SecureEnvelope.keyID(for: keys.signingPublicKey))
        #expect(ShareCode.isValid(code))
        #expect(!ShareCode.isValid("not-a-code"))
    }

    @Test func packageRoundTripsBetweenTwoDevices() throws {
        let fixture = try makeFixture()
        let sender = identity()
        let recipient = identity()

        let senderService = SharePackageService(identityProvider: { sender })
        let prepared = try senderService.prepareShare(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: ["Alpha"], categories: [.plantRecords, .environment]),
            recipientCode: ShareCode.encode(recipient)
        )

        let recipientService = SharePackageService(identityProvider: { recipient })
        let opened = try recipientService.openPackage(prepared.data, senderCode: ShareCode.encode(sender))

        #expect(opened == prepared.payload)
    }

    @Test func packageIsAddressedOnlyToItsRecipient() throws {
        let fixture = try makeFixture()
        let sender = identity()
        let recipient = identity()
        let stranger = identity()

        let senderService = SharePackageService(identityProvider: { sender })
        let prepared = try senderService.prepareShare(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: [], categories: [.plantRecords]),
            recipientCode: ShareCode.encode(recipient)
        )

        let strangerService = SharePackageService(identityProvider: { stranger })
        #expect(throws: SharePackageError.self) {
            try strangerService.openPackage(prepared.data, senderCode: ShareCode.encode(sender))
        }
    }

    @Test func packageFromAnotherSenderIsRejected() throws {
        let fixture = try makeFixture()
        let sender = identity()
        let impostor = identity()
        let recipient = identity()

        let senderService = SharePackageService(identityProvider: { sender })
        let prepared = try senderService.prepareShare(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: [], categories: [.plantRecords]),
            recipientCode: ShareCode.encode(recipient)
        )

        let recipientService = SharePackageService(identityProvider: { recipient })
        #expect(throws: SharePackageError.self) {
            try recipientService.openPackage(prepared.data, senderCode: ShareCode.encode(impostor))
        }
    }

    @Test func tamperedPackageIsRejected() throws {
        let fixture = try makeFixture()
        let sender = identity()
        let recipient = identity()

        let senderService = SharePackageService(identityProvider: { sender })
        var prepared = try senderService.prepareShare(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: [], categories: [.plantRecords]),
            recipientCode: ShareCode.encode(recipient)
        )

        var data = prepared.data
        let index = data.index(before: data.endIndex)
        data[index] ^= 0x01
        prepared = SharePackageService.PreparedShare(payload: prepared.payload, data: data, fileName: prepared.fileName)

        let recipientService = SharePackageService(identityProvider: { recipient })
        #expect(throws: SharePackageError.self) {
            try recipientService.openPackage(prepared.data, senderCode: ShareCode.encode(sender))
        }
    }

    @Test func expiredPackageIsRejected() throws {
        let fixture = try makeFixture()
        let sender = identity()
        let recipient = identity()

        var payload = SharePayloadBuilder.build(
            source: fixture.source,
            scope: scope(rooms: ["Tent A"], plants: [], categories: [.plantRecords])
        )
        payload.expiresAt = Date().addingTimeInterval(-60)

        let senderService = SharePackageService(identityProvider: { sender })
        let data = try senderService.makePackage(for: payload, recipientCode: ShareCode.encode(recipient))

        let recipientService = SharePackageService(identityProvider: { recipient })
        #expect(throws: SharePackageError.self) {
            try recipientService.openPackage(data, senderCode: ShareCode.encode(sender))
        }
    }

    @Test func emptyScopeIsRejected() throws {
        let fixture = try makeFixture()
        let service = SharePackageService(identityProvider: { identity() })

        #expect(throws: SharePackageError.self) {
            try service.prepareShare(
                source: fixture.source,
                scope: scope(rooms: [], plants: [], categories: [.plantRecords]),
                recipientCode: ShareCode.encode(identity())
            )
        }
    }

    @Test func newerPayloadFormatFailsClosed() throws {
        var payload = GrowSharePayload(
            formatVersion: 99,
            shareID: UUID(),
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86_400),
            scope: scope(rooms: ["Tent A"], plants: [], categories: [.plantRecords]),
            profile: nil,
            rooms: [],
            plants: [],
            readings: [],
            feedEvents: [],
            treatments: [],
            scoutingChecks: [],
            compliance: nil
        )
        payload.formatVersion = 99

        let data = try SharePackageService.encode(payload)
        #expect(throws: SharePackageError.self) {
            try SharePackageService.decode(data)
        }
    }
}
