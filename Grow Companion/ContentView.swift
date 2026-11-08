//
//  ContentView.swift
//  Grow Companion
//
//  Root gate: onboarding until a profile exists, education-only when the
//  jurisdiction does not permit home cultivation, the tracked app otherwise.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            content

            if appLock.isCovered || appLock.isLocked {
                LockOverlayView(appLock: appLock)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
            appLock.handle(scenePhase: phase)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let profile = profiles.first, profile.isOnboarded {
            if profile.educationOnly {
                EducationOnlyView(profile: profile)
            } else {
                MainTabView(profile: profile)
            }
        } else {
            OnboardingFlow()
        }
    }
}
