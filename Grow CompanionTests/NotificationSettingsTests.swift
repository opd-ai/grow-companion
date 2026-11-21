//
//  NotificationSettingsTests.swift
//  Grow CompanionTests
//
//  App-lock privacy must override detailed notification copy.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct NotificationSettingsTests {
    @Test func appLockAlwaysForcesGenericNotificationContent() {
        let defaults = UserDefaults.standard
        let keys = [SettingsKey.genericNotificationContent, SettingsKey.appLockEnabled]
        let previous = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for key in keys {
                if let value = previous[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.set(false, forKey: SettingsKey.genericNotificationContent)
        defaults.set(true, forKey: SettingsKey.appLockEnabled)
        #expect(NotificationSettings.shouldUseGenericContent)

        defaults.set(false, forKey: SettingsKey.appLockEnabled)
        #expect(!NotificationSettings.shouldUseGenericContent)

        defaults.set(true, forKey: SettingsKey.genericNotificationContent)
        #expect(NotificationSettings.shouldUseGenericContent)
    }
}
