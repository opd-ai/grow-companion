//
//  HarvestCalendarView.swift
//  Grow Companion
//
//  The whole grow's harvest calendar: each flowering plant's forecast window,
//  the day it is most likely to finish, and what is drying or curing now.
//

import SwiftUI
import SwiftData

struct HarvestCalendarView: View {
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \DryingSession.startedAt, order: .reverse) private var sessions: [DryingSession]

    @Environment(\.scenePhase) private var scenePhase

    @State private var monthAnchor = Date()
    @State private var now = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var forecasts: [HarvestForecast] {
        HarvestCalendar.forecasts(for: plants, now: now)
    }

    private var activeSessions: [DryingSession] {
        sessions.filter { $0.isActive }
    }

    private var monthDays: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor) else { return [] }

        let first = interval.start
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: first))
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var monthTitle: String {
        Self.monthFormatter.string(from: monthAnchor)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                calendarCard
                nextUpSection
                sessionsSection
                footerCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Harvest calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Harvest")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Windows come from your own flowering times where you have them")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: 12) {
            monthStrip
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(for: day)
                    } else {
                        Color.clear
                            .frame(height: 54)
                    }
                }
            }
        }
        .growCard(padding: 16)
    }

    private var monthStrip: some View {
        HStack {
            monthButton(systemImage: "chevron.left", label: "Previous month") {
                shiftMonth(-1)
            }
            Spacer()
            Text(monthTitle)
                .font(Theme.serif(20))
                .foregroundStyle(Theme.ink)
            Spacer()
            monthButton(systemImage: "chevron.right", label: "Next month") {
                shiftMonth(1)
            }
        }
    }

    private func monthButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.surfaceSunken))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index].uppercased())
                    .font(Theme.sans(9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.tertiaryInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let calendar = Calendar.current
        let number = calendar.component(.day, from: day)
        let dayForecasts = forecasts.filter { covers(day, $0) }
        let hasSession = activeSessions.contains { sessionCovers(day, $0) }
        let isToday = calendar.isDateInToday(day)

        return VStack(spacing: 2) {
            Text("\(number)")
                .font(.system(size: 10, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Theme.onHero : Theme.secondaryInk)
                .frame(width: 17, height: 17)
                .background(
                    Circle().fill(isToday ? Theme.primary : Color.clear)
                )

            if !dayForecasts.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(dayForecasts.prefix(2))) { forecast in
                        forecastBar(forecast, on: day)
                    }
                    if dayForecasts.count > 2 {
                        Text("+\(dayForecasts.count - 2)")
                            .font(.system(size: 6, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                }
            }

            Spacer(minLength: 0)

            if hasSession {
                Capsule()
                    .fill(Theme.secondaryInk.opacity(0.35))
                    .frame(height: 2)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            dayAccessibilityLabel(day, forecasts: dayForecasts, hasSession: hasSession)
        )
    }

    private func forecastBar(_ forecast: HarvestForecast, on day: Date) -> some View {
        let isLikely = Calendar.current.isDate(day, inSameDayAs: forecast.mostLikelyDate)
        let tint = forecast.isOverrun ? Theme.amber : Theme.primary

        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isLikely ? tint : tint.opacity(0.22))
            Text(initials(for: forecast.plant))
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(
                    isLikely
                        ? (forecast.isOverrun ? Theme.ink : Theme.onHero)
                        : Theme.primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(height: 9)
        .overlay(alignment: .trailing) {
            if isLikely {
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 3.5, height: 3.5)
                    .padding(.trailing, 2)
            }
        }
    }

    // MARK: Next up

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Next up", subtitle: nextUpSubtitle)

            if forecasts.isEmpty {
                Text("A plant gets a window the moment it moves into flower.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(padding: 16)
            } else {
                ForEach(forecasts) { forecast in
                    NavigationLink {
                        PlantDetailView(plant: forecast.plant)
                    } label: {
                        forecastCard(forecast)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nextUpSubtitle: String {
        guard !forecasts.isEmpty else { return "No plants in flower" }
        return "\(forecasts.count) window\(forecasts.count == 1 ? "" : "s") ahead"
    }

    private func forecastCard(_ forecast: HarvestForecast) -> some View {
        let plant = forecast.plant

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(plant.displayName)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("Flower week \(forecast.currentWeek) of \(forecast.weeks)")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }

            if let room = plant.room {
                HStack(spacing: 6) {
                    Pill(
                        text: room.name,
                        systemImage: room.type.systemImage,
                        tint: Theme.secondaryInk,
                        fill: Theme.surfaceSunken
                    )
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.dayMonthFormatter.string(from: forecast.mostLikelyDate))
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(forecast.timingText)
                    .font(Theme.sans(12))
                    .foregroundStyle(forecast.isOverrun ? Theme.amber : Theme.secondaryInk)
                Spacer(minLength: 0)
            }

            progressBar(forecast)

            Text(forecast.sourceText)
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .growCard(padding: 16)
    }

    private func progressBar(_ forecast: HarvestForecast) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceSunken)
                Capsule()
                    .fill(forecast.isOverrun ? Theme.amber : Theme.primary)
                    .frame(width: max(6, geometry.size.width * forecast.progress))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    // MARK: Drying and curing

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Drying and curing", subtitle: sessionsSubtitle)

            if activeSessions.isEmpty {
                Text("Nothing is drying or curing right now.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(activeSessions) { session in
                        sessionRow(session)
                        if session.id != activeSessions.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private var sessionsSubtitle: String {
        guard !activeSessions.isEmpty else { return "Nothing in progress" }
        return "\(activeSessions.count) in progress"
    }

    @ViewBuilder
    private func sessionRow(_ session: DryingSession) -> some View {
        let row = HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceSunken)
                    .frame(width: 32, height: 32)
                Image(systemName: session.phase == .curing ? "hourglass" : "wind")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.plant?.displayName ?? "Harvest")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(
                    session.phase == .curing
                        ? HarvestLog.curingDayText(session)
                        : HarvestLog.dryingDayText(session)
                )
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if let plant = session.plant {
            NavigationLink {
                PlantDetailView(plant: plant)
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    // MARK: Footer

    private var footerCard: some View {
        Text("A window opens when a plant enters flower and closes when it is harvested. Log the harvest and the next forecast uses what really happened.")
            .font(Theme.sans(12))
            .foregroundStyle(Theme.primary)
            .fixedSize(horizontal: false, vertical: true)
            .growCard(fill: Theme.sageSoft, padding: 16)
    }

    // MARK: Helpers

    private func covers(_ day: Date, _ forecast: HarvestForecast) -> Bool {
        let date = Calendar.current.startOfDay(for: day)
        return date >= forecast.windowStart && date <= forecast.windowEnd
    }

    private func sessionCovers(_ day: Date, _ session: DryingSession) -> Bool {
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: day)
        let beginning = session.phase == .curing
            ? (session.curingStartedAt ?? session.startedAt)
            : session.startedAt
        let start = calendar.startOfDay(for: beginning)
        let end = calendar.startOfDay(for: Date())
        return date >= start && date <= end
    }

    private func initials(for plant: Plant) -> String {
        let letters = plant.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let text = String(letters).uppercased()
        return text.isEmpty ? "?" : text
    }

    private func dayAccessibilityLabel(
        _ day: Date,
        forecasts: [HarvestForecast],
        hasSession: Bool
    ) -> String {
        var parts = [Self.dayMonthFormatter.string(from: day)]
        if forecasts.isEmpty {
            parts.append("No harvest window")
        } else {
            parts.append(forecasts.map { $0.plant.displayName }.joined(separator: ", "))
        }
        if hasSession {
            parts.append("Drying or curing in progress")
        }
        return parts.joined(separator: ". ")
    }

    private func shiftMonth(_ value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: monthAnchor) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            monthAnchor = next
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
