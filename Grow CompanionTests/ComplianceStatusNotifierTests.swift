//
//  ComplianceStatusNotifierTests.swift
//  Grow CompanionTests
//
//  Story 2: only a move towards a limit is announced, the first calculation is
//  a baseline, and the copy carries no garden names and no legal claim.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct ComplianceStatusNotifierTests {
    @Test func firstCalculationIsABaseline() {
        #expect(ComplianceStatusNotifier.change(previous: nil, current: .over) == nil)
        #expect(ComplianceStatusNotifier.change(previous: nil, current: .good) == nil)
    }

    @Test func worseningStatusNotifies() throws {
        #expect(try #require(change(.good, .warning)).shouldNotify)
        #expect(try #require(change(.warning, .over)).shouldNotify)
        #expect(try #require(change(.good, .over)).shouldNotify)
    }

    @Test func improvementDoesNotNotify() throws {
        #expect(try !#require(change(.over, .warning)).shouldNotify)
        #expect(try !#require(change(.over, .good)).shouldNotify)
        #expect(try !#require(change(.warning, .good)).shouldNotify)
    }

    @Test func unchangedStatusDoesNotNotify() throws {
        for level in ComplianceLevel.allCases {
            #expect(try !#require(change(level, level)).shouldNotify)
        }
    }

    @Test func unknownLevelsDoNotNotify() throws {
        #expect(try !#require(change(.unknown, .over)).shouldNotify)
        #expect(try !#require(change(.good, .unknown)).shouldNotify)
        #expect(try !#require(change(.unknown, .unknown)).shouldNotify)
    }

    @Test func contentNamesBothLevelsAndDisclaimsLegalAdvice() throws {
        let change = try #require(change(.good, .over))
        let content = ComplianceStatusNotifier.notification(for: change)

        #expect(content.title == "Compliance status changed")
        #expect(content.body.contains(ComplianceLevel.good.title.lowercased()))
        #expect(content.body.contains(ComplianceLevel.over.title.lowercased()))
        #expect(content.body.contains("not legal advice"))
    }

    @Test func identifierIsStablePerSnapshot() {
        let id = UUID()

        #expect(ComplianceStatusNotifier.identifier(for: id) == ComplianceStatusNotifier.identifier(for: id))
        #expect(ComplianceStatusNotifier.identifier(for: id) != ComplianceStatusNotifier.identifier(for: UUID()))
        #expect(ComplianceStatusNotifier.identifier(for: id).hasPrefix("compliance-status-"))
    }

    @Test func complianceCategoryIsTimeSensitiveAndListed() {
        #expect(NotificationCategory.allCases.contains(.compliance))
        #expect(NotificationCategory.compliance.defaultPriority == .timeSensitive)
        #expect(NotificationCategory.compliance.defaultPriority.interruptionLevel == .timeSensitive)
    }

    private func change(_ previous: ComplianceLevel, _ current: ComplianceLevel) -> ComplianceStatusChange? {
        ComplianceStatusNotifier.change(previous: previous, current: current)
    }
}
