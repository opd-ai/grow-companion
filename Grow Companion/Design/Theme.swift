//
//  Theme.swift
//  Grow Companion
//
//  Warm paper surfaces, deep forest green, and one dark card for the
//  compliance hero. Amber is reserved for caution, never for decoration.
//

import SwiftUI
import UIKit

enum Theme {
    static let background = Color(hex: 0xF3EFE6)
    static let backgroundDeep = Color(hex: 0xE9E3D6)
    static let surface = Color(hex: 0xFBF9F3)
    static let surfaceSunken = Color(hex: 0xF1ECE1)
    static let hero = Color(hex: 0x171A12)
    static let ink = Color(hex: 0x14170F)
    static let secondaryInk = Color(hex: 0x6B7062)
    static let tertiaryInk = Color(hex: 0x929789)
    static let primary = Color(hex: 0x2C5B39)
    static let primaryBright = Color(hex: 0x8FBE9B)
    static let sage = Color(hex: 0xAFC9AF)
    static let sageSoft = Color(hex: 0xE3EDE1)
    static let amber = Color(hex: 0xB07A22)
    static let amberBright = Color(hex: 0xE5B45F)
    static let amberSoft = Color(hex: 0xFAEEDA)
    static let danger = Color(hex: 0xA8493A)
    static let dangerBright = Color(hex: 0xE68A74)
    static let dangerSoft = Color(hex: 0xF8E3DC)
    static let onHero = Color(hex: 0xF6F3EA)
    static let onHeroSecondary = Color(hex: 0x9EA593)
    static let hairline = Color(hex: 0x14170F).opacity(0.07)

    static let cornerRadius: CGFloat = 24

    /// The design uses its own type scale, so the point sizes set here are the
    /// base sizes: they are scaled by the grower's Dynamic Type setting, which
    /// is what makes a reading, a stage or a plant name readable without
    /// zooming. The scale is capped because the densest cards — the compliance
    /// ring, the month grid, the metric strips — have a fixed shape to keep.
    static let maximumTypeScale: CGFloat = 1.45

    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size), weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .default)
    }

    /// The scaled point size for a base size at the current text-size setting.
    /// At the default setting it is the base size, so nothing moves for a
    /// grower who has not changed it.
    static func scaled(_ size: CGFloat) -> CGFloat {
        capped(UIFontMetrics(forTextStyle: .body).scaledValue(for: size), base: size)
    }

    /// Pure, so the cap is testable without a screen.
    static func capped(_ scaled: CGFloat, base: CGFloat) -> CGFloat {
        min(scaled, base * maximumTypeScale)
    }
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension ComplianceLevel {
    /// Tint for use on light surfaces.
    var tint: Color {
        switch self {
        case .good: return Theme.primary
        case .warning: return Theme.amber
        case .over: return Theme.danger
        case .unknown: return Theme.secondaryInk
        }
    }

    /// Brighter tint for the dark compliance card.
    var heroTint: Color {
        switch self {
        case .good: return Theme.primaryBright
        case .warning: return Theme.amberBright
        case .over: return Theme.dangerBright
        case .unknown: return Theme.onHeroSecondary
        }
    }

    var softFill: Color {
        switch self {
        case .good: return Theme.sageSoft
        case .warning: return Theme.amberSoft
        case .over: return Theme.dangerSoft
        case .unknown: return Theme.surfaceSunken
        }
    }
}
