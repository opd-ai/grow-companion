//
//  Grow_CompanionApp.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

@main
struct Grow_CompanionApp: App {
    let container: ModelContainer

    @State private var appLock = AppLock()

    init() {
        DataProtection.prepare()

        let schema = Schema([
            GrowProfile.self,
            Room.self,
            Plant.self,
            CycleArchive.self,
            Strain.self,
            StageEvent.self,
            JournalEntry.self,
            LightScheduleEvent.self,
            EnvironmentReading.self,
            SensorDevice.self,
            ShareGrant.self,
            ShareAccessLog.self,
            EnvironmentAlert.self,
            FeedEvent.self,
            CalibrationEvent.self,
            CareReminder.self,
            DryingSession.self,
            DryingCheck.self,
            CureBurp.self,
            TrainingSession.self,
            Treatment.self,
            Equipment.self,
            ServiceRecord.self,
            ScoutingCheck.self,
            FeedSchedule.self,
            FeedWeek.self,
            FeedProduct.self
        ])

        let configuration = ModelConfiguration("GrowCompanion", schema: schema)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Never strand the user: fall back to an in-memory store rather
            // than crashing on launch.
            let memoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            if let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfiguration]) {
                container = memoryContainer
            } else {
                fatalError("Could not open the on-device store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appLock)
        }
        .modelContainer(container)
    }
}
