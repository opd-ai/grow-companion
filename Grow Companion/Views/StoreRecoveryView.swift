//
//  StoreRecoveryView.swift
//  Grow Companion
//
//  Shown when the on-device store cannot be opened. Offers a retry and an
//  explicit new start that keeps the unreadable files, so the app never shows
//  an empty grow in place of records that are still on the device.
//

import SwiftUI

struct StoreRecoveryView: View {
    var boot: StoreBoot

    @State private var showingNewStart = false
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                explanationCard
                actionsCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .confirmationDialog(
            "Start a new grow?",
            isPresented: $showingNewStart,
            titleVisibility: .visible
        ) {
            Button("Start a new grow", role: .destructive) {
                startNewGrow()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The records that cannot be opened are moved into a folder on this device and kept. Nothing is deleted, and they are not uploaded anywhere.")
        }
        .alert("The new grow could not be started", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.hero)
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.primaryBright)
            }
            .frame(width: 64, height: 64)

            Text("Your records could not be opened")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Grow Companion keeps your grow in a protected store on this device. That store could not be opened just now.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What this means", subtitle: "Nothing has been deleted")

            Text("The app will not show an empty grow in place of records it cannot read, and it will not open a temporary store that looks like your data. Your grow files are still on this device.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("Try again first. If the store still cannot be opened, a verified backup can be restored from Settings → Backup and restore once the app opens again, or you can start a new grow.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if let message = boot.failureMessage {
                Divider().overlay(Theme.hairline)
                Text(message)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .growCard()
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Recovery", subtitle: "You choose what happens next")

            PrimaryButton("Try again", systemImage: "arrow.clockwise") {
                boot.open()
            }

            SecondaryButton("Start a new grow", systemImage: "plus.circle") {
                showingNewStart = true
            }

            Text("Starting a new grow moves the unreadable files into a folder beside the store and opens an empty one. They are kept, not deleted, so support can look at them if you ask.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private func startNewGrow() {
        do {
            try boot.startNewGrow()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
