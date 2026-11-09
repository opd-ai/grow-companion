//
//  EducationLibraryView.swift
//  Grow Companion
//
//  Offline learning library with local reading progress: which lessons have
//  been read, when, and a way to mark one unread again.
//

import SwiftUI
import SwiftData

struct EducationLibraryView: View {
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]

    @State private var progress = EducationReadingProgress.empty

    private var lessons: [EducationLesson] { EducationLibrary.lessons }

    private var readCount: Int { progress.count(in: lessons) }

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
        .onAppear { progress = EducationProgressStore.load() }
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
                    Text("\(readCount) of \(lessons.count) lessons read")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Theme.sage.opacity(0.4), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: lessons.isEmpty ? 0 : CGFloat(readCount) / CGFloat(lessons.count))
                        .stroke(Theme.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(readCount)")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            }
            ProgressView(value: Double(readCount), total: Double(max(lessons.count, 1)))
                .tint(Theme.primary)
                .accessibilityLabel(String(localized: "Your progress"))
                .accessibilityValue(String(localized: "\(readCount) of \(lessons.count) lessons read"))
        }
        .growCard(fill: Theme.sageSoft)
    }

    private func topicSection(_ topic: EducationTopic) -> some View {
        let topicLessons = EducationLibrary.lessons(for: topic)
        let topicRead = EducationLibrary.readCount(for: topic, in: progress)
        return VStack(alignment: .leading, spacing: 10) {
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
                    Text("\(topicRead) of \(topicLessons.count) read")
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                ForEach(topicLessons) { lesson in
                    NavigationLink {
                        EducationLessonView(
                            lesson: lesson,
                            isRead: progress.isRead(lesson.id),
                            readAt: progress.date(for: lesson.id),
                            toggleRead: { toggle(lesson) },
                            destination: destination(for: lesson)
                        )
                    } label: {
                        lessonRow(lesson)
                    }
                    .buttonStyle(.plain)
                    if lesson.id != topicLessons.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .growCard(padding: 14, radius: 20)
        }
    }

    private func lessonRow(_ lesson: EducationLesson) -> some View {
        let isRead = progress.isRead(lesson.id)
        let readOn = progress.date(for: lesson.id)
        return HStack(spacing: 12) {
            Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isRead ? Theme.primary : Theme.tertiaryInk)
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(lesson.summary)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
                if let readOn {
                    Text("Read on \(Format.shortDate(readOn))")
                        .font(Theme.sans(10, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(readValue(isRead: isRead, readOn: readOn))
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

    private func readValue(isRead: Bool, readOn: Date?) -> String {
        guard isRead else { return String(localized: "Not read yet") }
        guard let readOn else { return String(localized: "Read") }
        return String(localized: "Read on \(Format.shortDate(readOn))")
    }

    private func toggle(_ lesson: EducationLesson) {
        if progress.isRead(lesson.id) {
            progress = EducationProgressStore.markUnread(lesson.id)
        } else {
            progress = EducationProgressStore.markRead(lesson.id)
        }
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
    let isRead: Bool
    let readAt: Date?
    let toggleRead: () -> Void
    let destination: AnyView

    private var readLabel: String {
        guard let readAt else { return String(localized: "Read") }
        return String(localized: "Read on \(Format.shortDate(readAt))")
    }

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

                if let citation = lesson.rulePackCitation {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        Text(citation)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .growCard(fill: Theme.amberSoft, padding: 14)
                    .accessibilityElement(children: .combine)
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
                    toggleRead()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                        Text(isRead ? readLabel : String(localized: "Mark lesson complete"))
                        Spacer(minLength: 0)
                    }
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).stroke(Theme.primary.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .accessibilityHint(isRead
                    ? String(localized: "Marks this lesson unread again.")
                    : String(localized: "Marks this lesson as read and records the date."))
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
