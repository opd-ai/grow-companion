//
//  MainTabView.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    let profile: GrowProfile

    private enum Tab: Hashable {
        case home
        case journal
        case strains
        case rules
        case equipment
        case settings
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \CareReminder.nextDueDate) private var reminders: [CareReminder]
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var historyMonitor = ComplianceHistoryMonitor()
    @State private var selectedTab: Tab = .home

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

    /// Rewritten whenever a reminder's date, title or state changes, so the
    /// widget's shared snapshot is never stale after an edit.
    private var reminderSignature: String {
        reminders
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .map { "\($0.notificationIdentifier)-\($0.nextDueDate.timeIntervalSince1970)-\($0.displayTitle)-\($0.isEnabled)" }
            .joined(separator: "|")
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(profile: profile)
            }
            .tag(Tab.home)
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                JournalView()
            }
            .tag(Tab.journal)
            .tabItem { Label("Journal", systemImage: "book.closed") }

            NavigationStack {
                StrainLibraryView()
            }
            .tag(Tab.strains)
            .tabItem { Label("Strains", systemImage: "leaf") }

            NavigationStack {
                ComplianceView(profile: profile)
            }
            .tag(Tab.rules)
            .tabItem { Label("Rules", systemImage: "checkmark.shield") }

            NavigationStack {
                EquipmentView()
            }
            .tag(Tab.equipment)
            .tabItem { Label("Equipment", systemImage: "wrench.and.screwdriver") }

            NavigationStack {
                SettingsView(profile: profile)
            }
            .tag(Tab.settings)
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
        .task(id: reminderSignature) {
            WidgetSnapshotService.refresh(reminders: reminders)
        }
        .onOpenURL { url in
            // The widget opens today's care on the Home tab, inside whatever
            // lock or cover the app is already showing.
            guard url.scheme == "growcompanion" else { return }
            selectedTab = .home
        }
    }
}
