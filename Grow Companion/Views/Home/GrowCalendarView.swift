//
//  GrowCalendarView.swift
//  Grow Companion
//
//  One month of reminders, stage windows, harvest windows and drying or curing
//  checks. Everything is dated from the grower's own records; the only write
//  is a reminder move, confirmed with both dates named.
//

import SwiftUI
import SwiftData

struct GrowCalendarView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \CareReminder.nextDueDate) private var reminders: [CareReminder]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \DryingSession.startedAt, order: .reverse) private var dryingSessions: [DryingSession]

    @State private var visibleMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var editingReminder: CareReminder?

    private var calendar: Calendar { Calendar.current }

    private var entries: [GrowCalendarEntry] {
        GrowCalendarService.entries(
            from: GrowCalendarSources(
                reminders: reminders,
                plants: plants,
                dryingSessions: dryingSessions
            )
        )
    }

    private var groupedEntries: [Date: [GrowCalendarEntry]] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
    }

    private var overdue: [CareReminder] {
        GrowCalendarService.overdueReminders(from: reminders)
    }

    private var selectedEntries: [GrowCalendarEntry] {
        groupedEntries[calendar.startOfDay(for: selectedDay)] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !overdue.isEmpty {
                    overdueCard
                }

                monthCard
                dayCard
                footnote
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Grow calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingReminder) { reminder in
            RescheduleReminderSheet(reminder: reminder)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grow calendar")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Reminders, stage windows, harvest windows and drying or curing checks in one month. Moving a reminder asks first and re-schedules exactly one notification.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Missed tasks

    private var overdueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Missed tasks", subtitle: "Listed until you complete them")

            ForEach(overdue) { reminder in
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.amber)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.displayTitle)
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Was due \(Format.shortDate(reminder.nextDueDate))")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                    }

                    Spacer(minLength: 6)

                    Button {
                        complete(reminder)
                    } label: {
                        Text("Complete")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.surface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Complete \(reminder.displayTitle)")
                }
            }
        }
        .growCard(fill: Theme.amberSoft, padding: 14)
    }

    private func complete(_ reminder: CareReminder) {
        CareLog.complete(reminder)
        try? context.save()
    }

    // MARK: Month

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { shiftMonth(by: -1) } label: {
                    monthButton("chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous month")

                Spacer()

                Text(monthLabel)
                    .font(Theme.serif(24))
                    .foregroundStyle(Theme.ink)

                Spacer()

                Button { shiftMonth(by: 1) } label: {
                    monthButton("chevron.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next month")
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(gridDays, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .growCard(padding: 16)
    }

    private func dayCell(_ day: Date) -> some View {
        let dayEntries = groupedEntries[calendar.startOfDay(for: day)] ?? []
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let isInMonth = calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(Theme.sans(14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? Theme.onHero : (isInMonth ? Theme.ink : Theme.tertiaryInk)
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(
                            isSelected ? Theme.primary : (isToday ? Theme.sageSoft : Color.clear)
                        )
                    )

                Text(dayEntries.isEmpty ? "–" : "\(dayEntries.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(dayEntries.isEmpty ? Theme.tertiaryInk.opacity(0.4) : Theme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day: day, entries: dayEntries))
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }

    private func accessibilityLabel(day: Date, entries: [GrowCalendarEntry]) -> String {
        let date = Format.shortDate(day)
        guard !entries.isEmpty else { return String(localized: "\(date), nothing scheduled") }
        let kinds = entries.map(\.kind.title).joined(separator: ", ")
        return String(localized: "\(date), \(entries.count) item\(entries.count == 1 ? "" : "s"): \(kinds)")
    }

    // MARK: Selected day

    private var dayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDayLabel)
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)

            if selectedEntries.isEmpty {
                Text("Nothing scheduled on this day.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(fill: Theme.surface, padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(selectedEntries) { entry in
                        entryRow(entry)
                        if entry.id != selectedEntries.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private func entryRow(_ entry: GrowCalendarEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.sageSoft))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.kind.title)
                        .font(Theme.sans(10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer(minLength: 6)
                    if entry.reminder != nil {
                        Text(Format.time(entry.date))
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                }

                Text(entry.title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = entry.detail {
                    Text(detail)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let roomName = entry.roomName {
                    Pill(
                        text: roomName,
                        systemImage: "tent",
                        tint: Theme.secondaryInk,
                        fill: Theme.surfaceSunken
                    )
                }

                HStack(spacing: 16) {
                    if let plant = entry.plant {
                        NavigationLink {
                            PlantDetailView(plant: plant)
                        } label: {
                            Text("Open plant")
                                .font(Theme.sans(12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                    }

                    if let reminder = entry.reminder {
                        Button {
                            editingReminder = reminder
                        } label: {
                            Text("Move reminder")
                                .font(Theme.sans(12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Move \(reminder.displayTitle) to another day")
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.kind.title), \(entry.title)")
    }

    private var footnote: some View {
        Text("Stage and harvest windows are nudges from your own history and the breeder's figure, not deadlines. Nothing on this screen leaves the device.")
            .font(Theme.sans(12))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Month helpers

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        guard symbols.count == 7, (0..<7).contains(first) else { return symbols }
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var gridStart: Date {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        let first = calendar.date(from: components) ?? visibleMonth
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: first) ?? first
    }

    private var gridDays: [Date] {
        (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: visibleMonth)
    }

    private var selectedDayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: selectedDay)
    }

    private func shiftMonth(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: visibleMonth) else { return }
        visibleMonth = next
    }

    private func monthButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Theme.surfaceSunken))
    }
}

/// Confirms a reminder move with both dates named before anything changes.
struct RescheduleReminderSheet: View {
    let reminder: CareReminder

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var day = Date()
    @State private var confirming = false
    @State private var errorMessage = ""

    private var calendar: Calendar { Calendar.current }

    private var candidateDay: Date {
        calendar.startOfDay(for: day)
    }

    private var oldText: String {
        "\(Format.shortDate(reminder.nextDueDate)) at \(Format.time(reminder.nextDueDate))"
    }

    private var newText: String {
        let minutes = reminder.timeOfDayMinutes
        let date = calendar.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: candidateDay
        ) ?? candidateDay
        return String(localized: "\(Format.shortDate(date)) at \(Format.time(date))")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Move reminder")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("Changing the day keeps the time of day and re-schedules exactly one notification. The old one is cancelled.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("\(reminder.displayTitle) · new day")
                        DatePicker(
                            "New day",
                            selection: $day,
                            in: calendar.startOfDay(for: Date())...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Theme.primary)
                    }
                    .growCard(padding: 16)

                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(label: "Now", value: oldText)
                        InfoRow(label: "After", value: newText)
                    }
                    .growCard(padding: 16)

                    if !errorMessage.isEmpty {
                        CareInput.warning(errorMessage)
                    }

                    PrimaryButton(
                        "Move to \(Format.shortDate(candidateDay))",
                        systemImage: "calendar.badge.clock"
                    ) {
                        confirming = true
                    }

                    Button("Cancel") { dismiss() }
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .buttonStyle(.plain)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            day = max(reminder.nextDueDate, Date())
        }
        .confirmationDialog(
            "Move “\(reminder.displayTitle)” from \(oldText) to \(newText)?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Move to \(newText)") { apply() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func apply() {
        errorMessage = ""
        do {
            try GrowCalendarService.reschedule(
                reminder: reminder,
                to: candidateDay,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
