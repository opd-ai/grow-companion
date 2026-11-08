//
//  WeeklyRecapView.swift
//  Grow Companion
//
//  A read-only seven-day summary of the existing grow record.
//

import SwiftUI
import SwiftData

struct WeeklyRecapView: View {
    @Query private var plants: [Plant]
    @Query private var rooms: [Room]
    @Query private var journalEntries: [JournalEntry]
    @Query private var reminders: [CareReminder]
    @Query private var goals: [GrowGoal]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var currentGoal: GrowGoal? { GrowGoalService.current(from: goals) }

    private var goalSources: GrowGoalSources {
        GrowGoalSources(plants: plants, rooms: rooms, journal: journalEntries)
    }

    private var calendar: Calendar { Calendar.current }
    private var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart }
    private var nextWeekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekEnd) ?? weekEnd }
    private var weekRange: Range<Date> { weekStart..<weekEnd }

    private var stageMoves: [StageMove] {
        plants.flatMap { plant in
            let events = plant.sortedStageEvents
            return events.enumerated().compactMap { index, event -> StageMove? in
                guard weekRange.contains(event.date) else { return nil }
                let fromStage = index > 0 ? events[index - 1].stage : plant.origin.startingStage
                return StageMove(
                    id: event.persistentModelID,
                    plant: plant,
                    from: fromStage,
                    to: event.stage,
                    date: event.date
                )
            }
        }
        .sorted { $0.date < $1.date }
    }

    private var feedEvents: [FeedEvent] {
        rooms.flatMap(\.feedEvents).filter { weekRange.contains($0.date) }.sorted { $0.date < $1.date }
    }

    private var readingsOutOfRange: [RangeEvent] {
        rooms.flatMap { room in
            room.environmentReadings.flatMap { reading in
                guard weekRange.contains(reading.date) else { return [RangeEvent]() }
                var events: [RangeEvent] = []
                if let temperature = reading.temperatureC,
                   let target = room.targetTemperatureRange,
                   !target.contains(temperature) {
                    events.append(RangeEvent(
                        id: "temperature-\(reading.persistentModelID)",
                        room: room,
                        title: "\(room.name) · Temperature",
                        detail: "\(Format.temperature(temperature, unit: .metric)), target \(Format.temperatureRange(target, unit: .metric))",
                        date: reading.date
                    ))
                }
                if let humidity = reading.humidityPercent,
                   let target = room.targetHumidityRange,
                   !target.contains(humidity) {
                    events.append(RangeEvent(
                        id: "humidity-\(reading.persistentModelID)",
                        room: room,
                        title: "\(room.name) · RH",
                        detail: "\(String(format: "%.0f%%", humidity)), target \(String(format: "%.0f–%.0f%%", target.lowerBound, target.upperBound))",
                        date: reading.date
                    ))
                }
                return events
            }
        }
        .sorted { $0.date < $1.date }
    }

    private var weekJournal: [JournalEntry] {
        journalEntries.filter { weekRange.contains($0.createdAt) }.sorted { $0.createdAt < $1.createdAt }
    }

    private var upcomingTasks: [CareReminder] {
        reminders
            .filter { $0.isEnabled && $0.nextDueDate >= weekEnd && $0.nextDueDate < nextWeekEnd }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var hasActivity: Bool {
        !stageMoves.isEmpty || !feedEvents.isEmpty || !readingsOutOfRange.isEmpty || !weekJournal.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                weekHeader
                summaryCard
                GrowGoalsSection(goal: currentGoal, sources: goalSources, unit: unit)
                if !stageMoves.isEmpty { movedSection }
                if !readingsOutOfRange.isEmpty { outOfRangeSection }
                comingUpSection
                journalSummary
                if !hasActivity {
                    emptyWeekCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { moveWeek(by: -7) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 8) {
                    Text(weekLabel)
                        .font(Theme.sans(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        Capsule().fill(Theme.tertiaryInk.opacity(0.35)).frame(width: 62, height: 8)
                        Capsule().fill(Theme.primary).frame(width: 62, height: 8)
                        Capsule().fill(Theme.tertiaryInk.opacity(0.35)).frame(width: 62, height: 8)
                    }
                }
                Spacer()
                Button { moveWeek(by: 7) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Text("This week")
                .font(Theme.serif(42))
                .foregroundStyle(Theme.ink)
            Text("\(weekLabel) · All rooms")
                .font(Theme.sans(22))
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                summaryMetric(symbol: "arrow.up.and.down", value: stageMoves.count, label: "stage moves")
                Divider().frame(height: 72).overlay(Theme.onHero.opacity(0.18))
                summaryMetric(symbol: "drop", value: feedEvents.count, label: "feeds & waterings")
            }
            Divider().overlay(Theme.onHero.opacity(0.18))
            HStack(spacing: 0) {
                summaryMetric(symbol: "doc.text", value: weekJournal.count, label: "journal entries")
                Divider().frame(height: 72).overlay(Theme.onHero.opacity(0.18))
                summaryMetric(symbol: "exclamationmark.triangle", value: readingsOutOfRange.count, label: "readings out of range")
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.primary))
    }

    private func summaryMetric(symbol: String, value: Int, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.onHero)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.onHero.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.onHero)
                Text(label)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.onHero)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .accessibilityElement(children: .combine)
    }

    private var movedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("What moved")
            VStack(spacing: 0) {
                ForEach(stageMoves) { move in
                    NavigationLink { PlantDetailView(plant: move.plant) } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.sageSoft)
                                .frame(width: 48, height: 48)
                                .overlay(Image(systemName: move.to.systemImage).foregroundStyle(Theme.primary))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(move.plant.displayName).font(Theme.sans(16, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text("\(move.from.shortTitle) → \(move.to.shortTitle)").font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 6)
                            Text(Format.shortDate(move.date)).font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if move.id != stageMoves.last?.id { Divider().overlay(Theme.hairline) }
                }
            }
            .growCard(padding: 14)
        }
    }

    private var outOfRangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Out of range")
            VStack(spacing: 0) {
                ForEach(readingsOutOfRange) { item in
                    NavigationLink { RoomDetailView(room: item.room) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.amber)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(item.detail).font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 6)
                            Text(Format.shortDate(item.date)).font(Theme.sans(11)).foregroundStyle(Theme.secondaryInk)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if item.id != readingsOutOfRange.last?.id { Divider().overlay(Theme.hairline) }
                }
            }
            .growCard(fill: Theme.amberSoft, padding: 14)
        }
    }

    private var comingUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Coming up")
            if upcomingTasks.isEmpty {
                Text("Nothing is scheduled in the next seven days.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(fill: Theme.surface, padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(upcomingTasks) { reminder in
                        HStack(spacing: 12) {
                            Image(systemName: reminder.kind.systemImage)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.primary)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Theme.sageSoft))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.displayTitle).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(Format.shortDate(reminder.nextDueDate)).font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 5)
                            if let room = reminder.room {
                                Pill(text: room.name, systemImage: nil, tint: Theme.primary, fill: Theme.sageSoft)
                            }
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
                        }
                        .padding(.vertical, 10)
                        if reminder.id != upcomingTasks.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private var journalSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("The record")
            HStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.sageSoft))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(weekJournal.count) journal entr\(weekJournal.count == 1 ? "y" : "ies")")
                        .font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("\(weekJournal.filter { $0.photoFileName != nil }.count) photo\(weekJournal.filter { $0.photoFileName != nil }.count == 1 ? "" : "s") added this week")
                        .font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
                }
                Spacer(minLength: 0)
            }
            .growCard(fill: Theme.sageSoft, padding: 14)
        }
    }

    private var emptyWeekCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.primary)
            Text("A quiet week is still a week in the record.")
                .font(Theme.sans(15, weight: .medium))
                .foregroundStyle(Theme.primary)
            Spacer(minLength: 0)
        }
        .growCard(fill: Theme.sageSoft, padding: 16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(Theme.serif(29)).foregroundStyle(Theme.ink)
    }

    private var weekLabel: String {
        let end = calendar.date(byAdding: .day, value: -1, to: weekEnd) ?? weekStart
        let startDay = calendar.component(.day, from: weekStart)
        let endDay = calendar.component(.day, from: end)
        let startMonth = DateFormatter.monthFormatter.string(from: weekStart)
        let endMonth = DateFormatter.monthFormatter.string(from: end)
        if startMonth == endMonth { return "\(startDay)–\(endDay) \(startMonth)" }
        return "\(startDay) \(startMonth)–\(endDay) \(endMonth)"
    }

    private func moveWeek(by days: Int) {
        weekStart = calendar.date(byAdding: .day, value: days, to: weekStart) ?? weekStart
    }
}

private struct StageMove: Identifiable {
    let id: PersistentIdentifier
    let plant: Plant
    let from: PlantStage
    let to: PlantStage
    let date: Date
}

private struct RangeEvent: Identifiable {
    let id: String
    let room: Room
    let title: String
    let detail: String
    let date: Date
}

private extension DateFormatter {
    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
}
