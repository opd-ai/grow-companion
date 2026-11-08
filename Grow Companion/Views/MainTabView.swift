//
//  MainTabView.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    let profile: GrowProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var historyMonitor = ComplianceHistoryMonitor()

    /// The live calculation, kept at the tab root so the snapshot is recorded
    /// from the whole garden rather than from a filtered room view.
    private var complianceReport: ComplianceReport? {
        guard let rule = profile.rule else { return nil }
        return ComplianceEngine.report(
            plants: plants,
            rooms: rooms,
            rule: rule,
            warningThreshold: warningThreshold
        )
    }

    private var complianceSignature: String {
        guard let report = complianceReport else { return "no-rule" }
        return ComplianceHistoryService.fingerprint(
            report: report,
            stageCounts: ComplianceHistoryService.stageBuckets(for: plants),
            packVersion: RulePack.version
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(profile: profile)
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                JournalView()
            }
            .tabItem { Label("Journal", systemImage: "book.closed") }

            NavigationStack {
                StrainLibraryView()
            }
            .tabItem { Label("Strains", systemImage: "leaf") }

            NavigationStack {
                ComplianceView(profile: profile)
            }
            .tabItem { Label("Rules", systemImage: "checkmark.shield") }

            NavigationStack {
                EquipmentView()
            }
            .tabItem { Label("Equipment", systemImage: "wrench.and.screwdriver") }

            NavigationStack {
                SettingsView(profile: profile)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.primary)
        .toolbarBackground(Theme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(historyMonitor)
        .task(id: complianceSignature) {
            historyMonitor.sync(
                profile: profile,
                plants: plants,
                rooms: rooms,
                warningThreshold: warningThreshold,
                in: context
            )
        }
    }
}
