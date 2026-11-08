//
//  FeedScheduleSection.swift
//  Grow Companion
//
//  The current week's feed mix on a room, plus the shared pieces the schedule
//  library and editor use.
//

import SwiftUI

struct RoomFeedScheduleSection: View {
    let room: Room

    private var schedule: FeedSchedule? { room.feedSchedule }

    private var currentWeekNumber: Int? {
        guard let schedule else { return nil }
        return FeedScheduleEngine.currentWeek(
            startDate: room.feedScheduleStartDate,
            weekCount: schedule.weekCount
        )
    }

    private var currentWeek: FeedWeek? {
        guard let schedule, let currentWeekNumber else { return nil }
        return schedule.week(currentWeekNumber)
    }

    private var subtitle: String {
        guard let schedule else { return "No schedule applied" }
        if let status = FeedScheduleEngine.statusText(schedule: schedule, room: room) {
            return "\(schedule.displayName) · \(status)"
        }
        return schedule.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Feed schedule", subtitle: subtitle)

            if let schedule {
                if let week = currentWeek {
                    FeedWeekMixRows(week: week)
                    FeedWeekTargetPills(week: week)
                } else {
                    Text(emptyWeekMessage(schedule))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .growCard(fill: Theme.surfaceSunken, padding: 14)
                }
            } else {
                Text("No feed schedule applied to this room. Save a weekly mix and apply it here.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            }

            NavigationLink {
                FeedScheduleLibraryView(room: room)
            } label: {
                HStack {
                    Text(schedule == nil ? "Open feed schedules" : "Manage feed schedules")
                        .font(Theme.sans(13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private func emptyWeekMessage(_ schedule: FeedSchedule) -> String {
        if FeedScheduleEngine.isPending(startDate: room.feedScheduleStartDate) {
            let date = room.feedScheduleStartDate.map(Format.shortDate) ?? "soon"
            return "This schedule starts on \(date)."
        }
        if FeedScheduleEngine.isFinished(
            startDate: room.feedScheduleStartDate,
            weekCount: schedule.weekCount
        ) {
            return "All \(schedule.weekCount) weeks are complete. Duplicate the schedule for the next run."
        }
        return "No mix recorded for this week yet."
    }
}

struct FeedWeekMixRows: View {
    let week: FeedWeek

    var body: some View {
        VStack(spacing: 0) {
            if week.sortedProducts.isEmpty {
                Text("No products recorded for this week.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(week.sortedProducts) { product in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.sageSoft)
                                .frame(width: 26, height: 26)
                            Image(systemName: "flask")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }

                        Text(product.name)
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.ink)

                        Spacer(minLength: 8)

                        Text(FeedScheduleEngine.doseText(product.doseMLPerLiter))
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)

                    if product.id != week.sortedProducts.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
    }
}

struct FeedWeekTargetPills: View {
    let week: FeedWeek

    var body: some View {
        HStack(spacing: 6) {
            if let ph = week.targetPH {
                Pill(
                    text: "pH \(String(format: "%.1f", ph))",
                    systemImage: "paintpalette",
                    tint: Theme.primary,
                    fill: Theme.sageSoft
                )
            }
            if let ec = week.targetEC {
                Pill(
                    text: "EC \(String(format: "%.2f", ec))",
                    systemImage: "bolt.horizontal",
                    tint: Theme.primary,
                    fill: Theme.sageSoft
                )
            }
        }
    }
}
