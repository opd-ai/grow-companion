//
//  LockOverlayView.swift
//  Grow Companion
//
//  The neutral screen that covers the app while it is locked, and while it is
//  in the app switcher so the snapshot never shows grow data.
//

import SwiftUI

struct LockOverlayView: View {
    @Bindable var appLock: AppLock

    private var biometryName: String { AppLock.biometryName }

    private var biometrySymbol: String {
        switch biometryName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "lock.open"
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.hero)
                    Image(systemName: "leaf")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.primaryBright)
                }
                .frame(width: 64, height: 64)

                Text("Grow Companion")
                    .font(Theme.serif(24))
                    .foregroundStyle(Theme.ink)

                Text(appLock.isLocked ? lockedMessage : neutralMessage)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)

                if appLock.isLocked {
                    PrimaryButton("Unlock with \(biometryName)", systemImage: biometrySymbol) {
                        Task { await appLock.requestUnlock() }
                    }
                    .frame(maxWidth: 300)
                    .padding(.top, 6)
                }
            }
            .padding(28)
        }
        .task {
            if appLock.isLocked {
                await appLock.requestUnlock()
            }
        }
        .onChange(of: appLock.isLocked) { _, locked in
            if locked {
                Task { await appLock.requestUnlock() }
            }
        }
    }

    private var lockedMessage: String {
        "Your grow records are locked. Unlock to continue."
    }

    private var neutralMessage: String {
        "Locked"
    }
}
