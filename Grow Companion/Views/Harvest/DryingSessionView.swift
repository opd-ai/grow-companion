//
//  DryingSessionView.swift
//  Grow Companion
//
//  The drying and curing session: two big numbers against their target band,
//  the seven-day check strip, the latest checks, mold-risk guidance and the
//  progressive burping schedule.
//

import SwiftUI
import SwiftData

struct DryingSessionView: View {
    @Bindable var session: DryingSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingCheck = false
    @State private var showingStartCuring = false
    @State private var showingFinish = false

    private var plant: Plant? { session.plant }

    private var isCuring: Bool { session.phase == .curing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                heroCard
                latestRiskCard
                dailyChecksSection
                recentChecksSection
                if isCuring {
                    curingSection
                } else {
                    nextUpCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(session.phase.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showingCheck) {
            DryingCheckSheet(session: session)
        }
        .sheet(isPresented: $showingFinish) {
            FinishCuringSheet(session: session)
        }
        .confirmationDialog(
            "Start curing?",
            isPresented: $showingStartCuring,
            titleVisibility: .visible
        ) {
            Button("Start curing") { startCuring() }
            Button("Keep drying", role: .cancel) {}
        } message: {
            Text("Cure targets are 58–62% humidity. Burp daily for the first week, then every 2–3 days. The schedule can be adjusted from the curing section.")
        }
        .onChange(of: session.phase) { _, newValue in
            if newValue == .finished {
                dismiss()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plant?.displayName ?? "Harvest")
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
            Pill(
                text: session.profile.title,
                systemImage: session.profile == .hangDry ? "wind" : "fan",
                tint: Theme.primary,
                fill: Theme.sageSoft
            )
        }
    }

    private var subtitle: String {
        if isCuring {
            return HarvestLog.curingDayText(session)
        }
        return "Drying · " + HarvestLog.dryingDayText(session)
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 26) {
                heroValue(
                    title: "Humidity",
                    value: session.latestCheck?.humidityPercent.map { String(format: "%.0f%%", $0) } ?? "—"
                )
                heroValue(
                    title: "Temperature",
                    value: session.latestCheck?.temperatureC.map { String(format: "%.1f °C", $0) } ?? "—"
                )
            }

            Text("Target \(targetCaption)")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)

            TargetBandBar(
                value: session.latestCheck?.humidityPercent,
                range: humidityRange,
                domain: humidityDomain
            )

            Text("The sage band is the safe range for \(isCuring ? "curing" : session.profile.title.lowercased()).")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surface, padding: 20)
    }

    private func heroValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.serif(38))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var humidityRange: ClosedRange<Double> {
        isCuring ? session.curingHumidityRange : session.targetHumidityRange
    }

    private var humidityDomain: ClosedRange<Double> {
        isCuring ? 50...70 : 40...80
    }

    private var targetCaption: String {
        if isCuring {
            return "\(String(format: "%.0f–%.0f%%", humidityRange.lowerBound, humidityRange.upperBound)) humidity"
        }
        let temperature = session.targetTemperatureRange
        return "\(String(format: "%.0f–%.0f%%", humidityRange.lowerBound, humidityRange.upperBound)) · \(String(format: "%.0f–%.0f °C", temperature.lowerBound, temperature.upperBound))"
    }

    // MARK: Risk

    @ViewBuilder
    private var latestRiskCard: some View {
        if let check = session.latestCheck,
           let risk = HarvestLog.risk(for: check, session: session) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(risk.isCritical ? Theme.danger : Theme.amber)
                    Text(risk.title)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text(risk.message)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(risk.checklist.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.secondaryInk)
                        Text(item)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .growCard(fill: risk.isCritical ? Theme.dangerSoft : Theme.amberSoft)
        }
    }

    // MARK: Daily checks

    private var dailyChecksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Daily checks", subtitle: isCuring ? "Jar humidity over the last 7 days" : "Humidity and temperature over the last 7 days")

            HStack(spacing: 6) {
                ForEach(Array(stripDays.enumerated()), id: \.offset) { _, entry in
                    checkSquare(date: entry.date, check: entry.check)
                }
            }
        }
        .growCard()
    }

    private var stripDays: [(date: Date, check: DryingCheck?)] {
        HarvestLog.checksByDay(session)
    }

    private func checkSquare(date: Date, check: DryingCheck?) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(check != nil ? Theme.sage : Theme.surfaceSunken)
                .frame(height: 34)
            Text("\(dayNumber)")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(check != nil ? Theme.primary : Theme.tertiaryInk)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isToday ? Theme.primary : Color.clear, lineWidth: 2)
        )
        .accessibilityLabel(accessibilityLabel(for: date, check: check))
    }

    private func accessibilityLabel(for date: Date, check: DryingCheck?) -> String {
        let day = Format.shortDate(date)
        guard let check else { return "\(day), no check" }
        return "\(day), checked, \(HarvestLog.checkSummary(check, dayNumber: dayNumber(for: check)))"
    }

    // MARK: Recent checks

    private var recentChecksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Latest checks", subtitle: session.sortedChecks.isEmpty ? "None yet" : "\(session.sortedChecks.count) recorded")

            if session.sortedChecks.isEmpty {
                Text("Log the first check to start the record.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(session.sortedChecks.suffix(3).reversed())) { check in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(HarvestLog.checkSummary(check, dayNumber: dayNumber(for: check)))
                                    .font(Theme.sans(13, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 6)
                                Text(Format.time(check.date))
                                    .font(Theme.sans(10))
                                    .foregroundStyle(Theme.tertiaryInk)
                            }
                            if !check.note.isEmpty {
                                Text(check.note)
                                    .font(Theme.sans(11))
                                    .foregroundStyle(Theme.tertiaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)

                        if check.id != session.sortedChecks.suffix(3).first?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private func dayNumber(for check: DryingCheck) -> Int {
        HarvestLog.dayNumber(for: check, in: session)
    }

    // MARK: Next up

    private var nextUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Next up")
            Text("Cure begins when stems snap cleanly")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Below 55% dries too fast — slow it down by lowering airflow.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.amber)
                .fixedSize(horizontal: false, vertical: true)
            Text("Drying usually takes \(session.profile.expectedDryDays.lowerBound)–\(session.profile.expectedDryDays.upperBound) days at \(session.profile.title.lowercased()) conditions.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    // MARK: Curing

    private var curingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Curing & burping", subtitle: "\(String(format: "%.0f–%.0f%%", session.curingHumidityRange.lowerBound, session.curingHumidityRange.upperBound)) humidity")

            if let next = HarvestLog.nextBurpDate(session) {
                let overdue = next < Date()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(overdue ? Theme.amber : Theme.primary)
                    Text(overdue
                         ? "Burp overdue since \(Format.shortDate(next)) — open the jars and check humidity."
                         : "Next burp \(Format.shortDate(next)) at \(Format.time(next)).")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(overdue ? Theme.amberSoft : Theme.sageSoft)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                CareInput.label("Burping schedule")
                Menu {
                    ForEach(BurpMode.allCases) { mode in
                        Button {
                            session.burpMode = mode
                            try? context.save()
                            HarvestLog.scheduleBurpNotification(session)
                        } label: {
                            Label(mode.title, systemImage: mode == session.burpMode ? "checkmark" : "clock")
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wind")
                            .font(.system(size: 13, weight: .semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.burpMode.title)
                                .font(Theme.sans(14, weight: .semibold))
                            Text(session.burpMode.subtitle)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.sageSoft)
                    )
                }

                Text("The schedule is guidance, not a rule. Adjust it to how the jars look and smell.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecondaryButton("Log burp", systemImage: "wind") {
                HarvestLog.logBurp(session, context: context)
            }

            if !session.sortedBurps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(session.sortedBurps.prefix(3))) { burp in
                        HStack {
                            Text("Burped")
                                .font(Theme.sans(13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(Format.shortDate(burp.date)) · \(Format.time(burp.date))")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .padding(.vertical, 7)
                        .accessibilityElement(children: .combine)

                        if burp.id != session.sortedBurps.prefix(3).last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(fill: Theme.surfaceSunken, padding: 14)
            }
        }
        .growCard()
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryButton("Log today's check", systemImage: "plus") {
                showingCheck = true
            }

            if session.phase == .drying {
                Button("End drying and start curing") {
                    showingStartCuring = true
                }
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.primary)
            } else if session.phase == .curing {
                Button("Finish curing") {
                    showingFinish = true
                }
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    // MARK: Actions

    private func startCuring() {
        session.phase = .curing
        session.curingStartedAt = Date()

        if let plant, plant.stage != .cure {
            let event = StageEvent(stage: .cure, date: Date())
            context.insert(event)
            event.plant = plant
            plant.stage = .cure
        }

        try? context.save()

        Task {
            _ = await CareNotifications.requestAuthorization()
            HarvestLog.scheduleBurpNotification(session)
        }
    }
}

// MARK: - Target band bar

struct TargetBandBar: View {
    let value: Double?
    let range: ClosedRange<Double>
    let domain: ClosedRange<Double>

    private var isOut: Bool {
        guard let value else { return false }
        return !range.contains(value)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let span = max(domain.upperBound - domain.lowerBound, 0.001)
            let lowerX = CGFloat((range.lowerBound - domain.lowerBound) / span) * width
            let upperX = CGFloat((range.upperBound - domain.lowerBound) / span) * width
            let bandWidth = max(8, upperX - lowerX)
            let markerX: CGFloat? = value.map { raw in
                let clamped = min(max(raw, domain.lowerBound), domain.upperBound)
                return CGFloat((clamped - domain.lowerBound) / span) * width
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceSunken)
                    .frame(height: 8)

                Capsule()
                    .fill(Theme.sage)
                    .frame(width: bandWidth, height: 8)
                    .offset(x: lowerX)

                if let markerX {
                    Capsule()
                        .fill(isOut ? Theme.danger : Theme.primary)
                        .frame(width: 3, height: 18)
                        .offset(x: max(0, min(width - 3, markerX - 1.5)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let band = String(format: "%.0f to %.0f", range.lowerBound, range.upperBound)
        guard let value else { return "Target band \(band). No reading yet." }
        return "Reading \(String(format: "%.0f", value)), target band \(band)\(isOut ? ", outside the band" : "")"
    }
}
