//
//  AppLockTests.swift
//  Grow CompanionTests
//
//  A device that cannot authenticate must not enable a lock that can strand the grower.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct AppLockTests {
    @Test func lockCannotBeEnabledWhenDeviceAuthenticationIsUnavailable() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: SettingsKey.appLockEnabled)
        defaults.set(false, forKey: SettingsKey.appLockEnabled)
        defer {
            if let previous {
                defaults.set(previous, forKey: SettingsKey.appLockEnabled)
            } else {
                defaults.removeObject(forKey: SettingsKey.appLockEnabled)
            }
        }

        let lock = AppLock()
        lock.setEnabled(true, authenticationCheck: { false })

        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        #expect(lock.authenticationUnavailable)
    }
}
