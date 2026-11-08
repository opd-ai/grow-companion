//
//  MainTabView.swift
//  Grow Companion
//

import SwiftUI

struct MainTabView: View {
    let profile: GrowProfile

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
    }
}
