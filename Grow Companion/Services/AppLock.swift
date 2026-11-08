//
//  AppLock.swift
//  Grow Companion
//
//  Face ID (with the device passcode as fallback) in front of the whole app,
//  a configurable grace period, and a neutral screen that covers the app while
//  it is in the app switcher.
//

import Foundation
import LocalAuthentication
import Observation
import SwiftUI

enum LockGrace: Int, CaseIterable, Identifiable, Hashable {
    case immediate = 0
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .immediate: return "Immediate"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        }
    }

    var detailText: String {
        switch self {
        case .immediate:
            return "The app asks for Face ID every time it comes back, however short the break."
        case .oneMinute:
            return "The app stays open for a minute after you leave it, then asks for Face ID."
        case .fiveMinutes:
            return "The app stays open for five minutes after you leave it, then asks for Face ID."
        }
    }

    var seconds: TimeInterval { TimeInterval(rawValue) }
}

@Observable
final class AppLock {
    /// Whether the app is currently covered by the lock screen.
    var isLocked: Bool

    /// True while the neutral screen is up: either locked, or in the app
    /// switcher with the app in the background.
    var isCovered: Bool

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: SettingsKey.appLockEnabled)
            if !isEnabled {
                isLocked = false
                isCovered = false
            }
            updateCover()
        }
    }

    var grace: LockGrace {
        didSet {
            UserDefaults.standard.set(grace.rawValue, forKey: SettingsKey.appLockGrace)
        }
    }

    private var backgroundedAt: Date?
    private var isAuthenticating = false

    init() {
        let defaults = UserDefaults.standard
        let storedEnabled = defaults.object(forKey: SettingsKey.appLockEnabled) as? Bool ?? false
        let storedGrace = LockGrace(rawValue: defaults.integer(forKey: SettingsKey.appLockGrace)) ?? .immediate

        isEnabled = storedEnabled
        grace = storedGrace
        isLocked = storedEnabled
        isCovered = storedEnabled
    }

    // MARK: Lifecycle

    func handle(scenePhase: ScenePhase) {
        guard isEnabled else {
            isLocked = false
            isCovered = false
            return
        }

        switch scenePhase {
        case .active:
            if let backgroundedAt, Date().timeIntervalSince(backgroundedAt) > grace.seconds {
                isLocked = true
            }
            backgroundedAt = nil
            isCovered = isLocked
        case .inactive:
            // Covers the app-switcher snapshot before the app is suspended.
            isCovered = true
        case .background:
            if !isLocked { backgroundedAt = Date() }
            isCovered = true
        @unknown default:
            break
        }

        updateCover()
    }

    func lockNow() {
        guard isEnabled else { return }
        isLocked = true
        isCovered = true
        updateCover()
    }

    // MARK: Authentication

    func requestUnlock() async {
        guard isEnabled, isLocked else {
            isLocked = false
            isCovered = false
            updateCover()
            return
        }
        guard !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Keep locked"
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Never fail open. The user must configure a device passcode before
            // protected records can be unlocked.
            isLocked = true
            isCovered = true
            updateCover()
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your grow records"
            )
            if success {
                isLocked = false
                isCovered = false
                updateCover()
            }
        } catch {
            // Stay locked; the unlock button remains.
        }
    }

    /// Called by the delete-all flow: the lock and its settings go with the data.
    func resetForDataErase() {
        isLocked = false
        isCovered = false
        isEnabled = false
        grace = .immediate
        backgroundedAt = nil
        UserDefaults.standard.removeObject(forKey: SettingsKey.appLockEnabled)
        UserDefaults.standard.removeObject(forKey: SettingsKey.appLockGrace)
        updateCover()
    }

    private func updateCover() {
        if isCovered || isLocked {
            PrivacyCover.shared.show(appLock: self)
        } else {
            PrivacyCover.shared.hide()
        }
    }

    // MARK: Status

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    static var hasBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var statusText: String {
        isEnabled ? "On · \(grace.shortTitle.lowercased())" : "Off"
    }
}
