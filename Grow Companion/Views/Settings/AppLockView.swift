//
//  AppLockView.swift
//  Grow Companion
//
//  Turn the app lock on, choose how long the app may be away before it asks
//  again, and lock it on demand.
//

import SwiftUI

struct AppLockView: View {
    @Environment(AppLock.self) private var appLock

    var body: some View {
        @Bindable var lock = appLock

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("App lock")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text("\(AppLock.biometryName) keeps the app closed to anyone else, and a neutral screen covers it in the app switcher.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Lock")
                    Toggle(isOn: $lock.isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Require \(AppLock.biometryName)")
                                .font(Theme.sans(15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(fallbackText)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Theme.primary)
                }
                .growCard()

                if lock.isEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Grace period", subtitle: "How long the app may be away before it asks again")
                        Picker("Grace period", selection: $lock.grace) {
                            ForEach(LockGrace.allCases) { grace in
                                Text(grace.shortTitle).tag(grace)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(lock.grace.detailText)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)

                        SecondaryButton("Lock now", systemImage: "lock") {
                            appLock.lockNow()
                        }
                    }
                    .growCard()
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("How it behaves")
                    bullet("The app locks when it comes back from the background, once the grace period has passed.")
                    bullet("A neutral screen replaces the app-switcher snapshot, so no plant, room or strain appears there.")
                    bullet("If the device has no passcode, the app cannot lock and stays open.")
                }
                .growCard()
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("App lock")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fallbackText: String {
        AppLock.hasBiometrics
            ? "Your device passcode is the fallback if \(AppLock.biometryName) cannot see you."
            : "No biometrics set up on this device, so your passcode is used."
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(Theme.primary)
                .padding(.top, 6)
            Text(text)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
