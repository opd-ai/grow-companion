//
//  EducationLibraryView.swift
//  Grow Companion
//
//  Offline learning library with local reading progress.
//

import SwiftUI
import SwiftData

struct EducationLibraryView: View {
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]

    @State private var completedIDs: Set<String> = []

    private var completedCount: Int {
        EducationLibrary.lessons.filter { completedIDs.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                progressCard
                ForEach(EducationTopic.allCases) { topic in
                    topicSection(topic)
                }
                offlineNote
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { completedIDs = EducationProgress.completedLessonIDs }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Learn as you grow")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Practical guidance, reviewed and kept on this device.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    SectionHeader("Your progress")
                    Text("\(completedCount) of \(EducationLibrary.lessons.count) lessons completed")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Theme.sage.opacity(0.4), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: EducationLibrary.lessons.isEmpty ? 0 : CGFloat(completedCount) / CGFloat(EducationLibrary.lessons.count))
                        .stroke(Theme.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(completedCount)")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
                .frame(width: 48, height: 48)
            }
            ProgressView(value: Double(completedCount), total: Double(max(EducationLibrary.lessons.count, 1)))
                .tint(Theme.primary)
        }
        .growCard(fill: Theme.sageSoft)
    }

    private func topicSection(_ topic: EducationTopic) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: topic.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(topic.subtitle)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }
            }

            VStack(spacing: 0) {
                ForEach(EducationLibrary.lessons(for: topic)) { lesson in
                    NavigationLink {
                        EducationLessonView(
                            lesson: lesson,
                            isComplete: completedIDs.contains(lesson.id),
                            markComplete: { markComplete(lesson) },
                            destination: destination(for: lesson)
                        )
                    } label: {
                        lessonRow(lesson)
                    }
                    .buttonStyle(.plain)
                    if lesson.id != EducationLibrary.lessons(for: topic).last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .growCard(padding: 14, radius: 20)
        }
    }

    private func lessonRow(_ lesson: EducationLesson) -> some View {
        HStack(spacing: 12) {
            Image(systemName: completedIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(completedIDs.contains(lesson.id) ? Theme.primary : Theme.tertiaryInk)
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(lesson.summary)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var offlineNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.icloud")
                .foregroundStyle(Theme.primary)
            Text("Lessons and reading progress are available offline. Guidance is educational and does not replace current legal requirements, product labels or professional advice.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)
    }

    private func markComplete(_ lesson: EducationLesson) {
        completedIDs.insert(lesson.id)
        EducationProgress.setCompleted(lesson.id, completed: true)
    }

    private func destination(for lesson: EducationLesson) -> AnyView {
        switch lesson.destination {
        case .room:
            if let room = rooms.first {
                AnyView(RoomDetailView(room: room))
            } else {
                AnyView(Text("Create a room to apply this lesson.").foregroundStyle(Theme.secondaryInk))
            }
        case .plant:
            if let plant = plants.first {
                AnyView(PlantDetailView(plant: plant))
            } else {
                AnyView(Text("Add a plant to apply this lesson.").foregroundStyle(Theme.secondaryInk))
            }
        case .compliance:
            if let profile = profiles.first {
                AnyView(ComplianceView(profile: profile))
            } else {
                AnyView(Text("Complete jurisdiction setup to apply this lesson.").foregroundStyle(Theme.secondaryInk))
            }
        }
    }
}

private struct EducationLessonView: View {
    let lesson: EducationLesson
    let isComplete: Bool
    let markComplete: () -> Void
    let destination: AnyView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Pill(text: lesson.topic.title, systemImage: lesson.topic.systemImage)
                    Text(lesson.title)
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text(lesson.summary)
                        .font(Theme.sans(15))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Reviewed \(lesson.reviewedLabel)")
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Quick checklist", subtitle: "Use this as a prompt in your own records")
                    ForEach(lesson.checklist, id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Theme.primary)
                            Text(item)
                                .font(Theme.sans(14))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .growCard()

                NavigationLink {
                    destination
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Apply to my grow")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.onHero)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.primary))
                }
                .buttonStyle(.plain)

                Button {
                    markComplete()
                } label: {
                    HStack {
                        Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        Text(isComplete ? "Lesson completed" : "Mark lesson complete")
                    }
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).stroke(Theme.primary.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum EducationProgress {
    private static let key = SettingsKey.educationCompletedLessons

    static var completedLessonIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func setCompleted(_ id: String, completed: Bool) {
        var ids = completedLessonIDs
        if completed { ids.insert(id) } else { ids.remove(id) }
        UserDefaults.standard.set(Array(ids).sorted(), forKey: key)
    }
}
