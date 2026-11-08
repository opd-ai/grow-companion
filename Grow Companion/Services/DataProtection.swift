//
//  DataProtection.swift
//  Grow Companion
//
//  Puts the whole on-device store under complete file protection, so records
//  are unreadable while the device is locked.
//

import Foundation

enum DataProtection {
    static func prepare() {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        if !manager.fileExists(atPath: base.path) {
            try? manager.createDirectory(
                at: base,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        }

        try? manager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: base.path
        )

        if let enumerator = manager.enumerator(at: base, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                try? manager.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: url.path
                )
            }
        }
    }
}
