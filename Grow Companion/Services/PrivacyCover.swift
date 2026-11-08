//
//  PrivacyCover.swift
//  Grow Companion
//
//  A window-level neutral cover, so the app-switcher snapshot never shows the
//  app's content — even when a sheet or alert is on screen.
//

import SwiftUI
import UIKit

final class PrivacyCover {
    static let shared = PrivacyCover()

    private var coverWindow: UIWindow?

    func show(appLock: AppLock) {
        guard coverWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: {
                $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
            })
        else { return }

        let host = UIHostingController(rootView: LockOverlayView(appLock: appLock))
        host.view.backgroundColor = .clear

        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false

        coverWindow = window
    }

    func hide() {
        coverWindow?.isHidden = true
        coverWindow = nil
    }
}
