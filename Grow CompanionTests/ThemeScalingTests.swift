//
//  ThemeScalingTests.swift
//  Grow CompanionTests
//
//  The type scale follows the grower's text-size setting, and the cap keeps
//  the densest cards in one piece at the largest settings.
//

import CoreGraphics
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct ThemeScalingTests {
    @Test func theCapOnlyAppliesPastTheLimit() {
        #expect(Theme.capped(13, base: 13) == 13)
        #expect(Theme.capped(15, base: 13) == 15)
    }

    @Test func theCapStopsTheLargestAccessibilitySizes() {
        let ceiling = 13 * Theme.maximumTypeScale

        #expect(Theme.capped(60, base: 13) == ceiling)
        #expect(Theme.capped(ceiling, base: 13) == ceiling)
    }

    @Test func aBaseSizeIsNeverShrunk() {
        for size in [11, 12, 13, 15, 22, 30, 42] as [CGFloat] {
            let scaled = Theme.scaled(size)

            #expect(scaled >= size)
            #expect(scaled <= size * Theme.maximumTypeScale)
        }
    }
}
