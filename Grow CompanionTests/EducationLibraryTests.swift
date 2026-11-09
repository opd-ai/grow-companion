//
//  EducationLibraryTests.swift
//  Grow CompanionTests
//
//  The lesson content and the reading progress: every topic covered, copy
//  limits, the rule pack the legal lesson was written against, and a progress
//  store that records a date, can be un-marked and is cleared by delete-all.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct EducationLibraryTests {
    @Test func everyTopicHasAtLeastOneLesson() {
        for topic in EducationTopic.allCases {
            #expect(!EducationLibrary.lessons(for: topic).isEmpty, "\(topic.rawValue) has no lessons")
        }
    }

    @Test func lessonIDsAreUniqueAndCoverTheLibrary() {
        let ids = EducationLibrary.lessons.map(\.id)

        #expect(!ids.isEmpty)
        #expect(ids.count == Set(ids).count)
        for id in ids {
            #expect(EducationLibrary.lesson(withID: id)?.id == id)
        }
    }

    @Test func everyLessonCarriesCopyAChecklistAndAReviewDate() {
        for lesson in EducationLibrary.lessons {
            #expect(!lesson.title.isEmpty)
            #expect(!lesson.summary.isEmpty)
            #expect(lesson.checklist.count >= 3)
            #expect(!lesson.reviewedLabel.isEmpty)
            #expect(lesson.reviewedOn <= Date())
        }
    }

    @Test func everyLessonHasAUsefulApplyDestination() {
        let destinations = Set(EducationLibrary.lessons.map(\.destination))

        #expect(destinations.contains(.room))
        #expect(destinations.contains(.plant))
        #expect(destinations.contains(.compliance))
    }

    @Test func theRulesLessonCitesTheRulePackAndOnlyThatLessonDoes() throws {
        let legal = try #require(
            EducationLibrary.lessons.first { $0.topic == .compliance }
        )

        #expect(legal.citesRulePack)
        #expect(legal.rulePackCitation?.contains(RulePack.version) == true)
        #expect(legal.rulePackCitation?.contains(RulePack.displayDate(RulePack.verifiedOn)) == true)

        let others = EducationLibrary.lessons.filter { $0.topic != .compliance }
        #expect(others.allSatisfy { !$0.citesRulePack })
    }

    @Test func theLibraryNamesNoProductOrHealthClaim() {
        let forbidden = [
            "neem", "spinosad", "pyrethrin", "insecticidal", "hydrogen peroxide",
            "bleach", "buy ", "purchase", "brand", "thc", "cannabinoid", "potency"
        ]

        for lesson in EducationLibrary.lessons {
            let copy = (lesson.title + " " + lesson.summary + " " + lesson.checklist.joined(separator: " "))
                .lowercased()
            for word in forbidden {
                #expect(!copy.contains(word), "\(lesson.id) mentions \(word)")
            }
        }
    }

    @Test func theReviewDateMatchesTheRulePack() {
        #expect(EducationLibrary.reviewDate == RulePack.verifiedDate)
    }
}

@Suite(.serialized)
struct EducationProgressTests {
    @Test func nothingIsReadToBeginWith() throws {
        let defaults = try educationDefaults()

        let progress = EducationProgressStore.load(from: defaults)

        #expect(progress.completed.isEmpty)
        #expect(progress.readAt.isEmpty)
        #expect(progress.count(in: EducationLibrary.lessons) == 0)
        #expect(!progress.allRead(in: EducationLibrary.lessons))
    }

    @Test func readingALessonRecordsTheIDAndTheDate() throws {
        let defaults = try educationDefaults()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let progress = EducationProgressStore.markRead(
            "fundamentals-room-routine",
            at: date,
            in: defaults
        )

        #expect(progress.isRead("fundamentals-room-routine"))
        #expect(progress.date(for: "fundamentals-room-routine") == date)
        #expect(progress.count(in: EducationLibrary.lessons) == 1)
        #expect(EducationProgressStore.load(from: defaults) == progress)
    }

    @Test func markingUnreadClearsTheDateAndTheID() throws {
        let defaults = try educationDefaults()
        EducationProgressStore.markRead("pests-scouting", in: defaults)

        let progress = EducationProgressStore.markUnread("pests-scouting", in: defaults)

        #expect(!progress.isRead("pests-scouting"))
        #expect(progress.date(for: "pests-scouting") == nil)
        #expect(defaults.dictionary(forKey: SettingsKey.educationLessonReadAt) == nil)
    }

    @Test func aTopicCountsOnlyItsOwnLessons() throws {
        let defaults = try educationDefaults()
        EducationProgressStore.markRead("pests-scouting", in: defaults)

        let progress = EducationProgressStore.load(from: defaults)

        #expect(EducationLibrary.readCount(for: .pestManagement, in: progress) == 1)
        #expect(EducationLibrary.readCount(for: .fundamentals, in: progress) == 0)
    }

    @Test func allReadNeedsEveryLesson() {
        let lessons = EducationLibrary.lessons
        var progress = EducationReadingProgress()

        #expect(!progress.allRead(in: []))
        #expect(!progress.allRead(in: lessons))

        progress.completed = Set(lessons.map(\.id))

        #expect(progress.allRead(in: lessons))
    }

    @Test func readingProgressIsClearedByDeleteAll() {
        #expect(SettingsKey.all.contains(SettingsKey.educationCompletedLessons))
        #expect(SettingsKey.all.contains(SettingsKey.educationLessonReadAt))
    }
}

private func educationDefaults() throws -> UserDefaults {
    let name = "EducationLibraryTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return defaults
}
