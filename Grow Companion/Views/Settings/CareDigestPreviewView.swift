//
//  CareDigestPreviewView.swift
//  Grow Companion
//
//  Read-only preview of the local care digest for the selected rooms.
//

import SwiftUI
import SwiftData

struct CareDigestPreviewView: View {
    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @State private var selectedRoomIDs: Set<String> = []
    @State private var digestDate = Calendar.current.startOfDay(for: Date())

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var calendar: Calendar { Calendar.current }
    private var selectedRooms: [Room] {
        CareDigest.selectedRooms(from: rooms, roomIDs: selectedRoomIDs)
    }
    private var snapshot: CareDigestSnapshot {
        CareDigest.snapshot(for: selectedRooms, digestDate: digestDate)
    }
    private var activityItems: [CareDigestActivityItem] {
        let feeds = snapshot.feedEvents.map { event in
            CareDigestActivityItem(
                id: "feed-\(event.persistentModelID)",
                date: event.date,
                roomName: event.room?.name ?? "Room",
                title: event.kind.title,
                detail: feedDetail(event),
                symbol: event.kind.systemImage
            )
        }
        let readings = snapshot.environmentReadings.map { reading in
            CareDigestActivityItem(
                id: "reading-\(reading.persistentModelID)",
                date: reading.date,
                roomName: reading.room?.name ?? "Room",
                title: "Environment reading",
                detail: readingDetail(reading),
                symbol: "thermometer.medium"
            )
        }
        let calibrations = snapshot.calibrationEvents.map { event in
            CareDigestActivityItem(
                id: "calibration-\(event.persistentModelID)",
                date: event.date,
                roomName: event.room?.name ?? "Room",
                title: "\(event.meter.title) calibration",
                detail: event.reading.map { String(format: "Reading %.2f", $0) } ?? "Calibration saved",
                symbol: event.meter.systemImage
            )
        }
        return (feeds + readings + calibrations).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading
                dateSelector

                if selectedRooms.isEmpty {
                    noRoomsCard
                } else {
                    roomScope
                    activitySection
                    unfinishedTasksSection
                }

                Text("This is a read-only preview. It does not change reminders or create records.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Care digest")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedRoomIDs = CareDigestPreferences.current.roomIDs
            digestDate = calendar.startOfDay(for: Date())
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Care digest")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("A clear look at recorded care and tasks still unfinished.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Digest date", subtitle: "Today and the six days before")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { daysBack in
                        let date = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: Date())) ?? Date()
                        dateButton(for: date, isToday: daysBack == 0)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Text("Activity covers the previous calendar day. Unfinished tasks are those already overdue when this digest is prepared.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(padding: 14)
    }

    private func dateButton(for date: Date, isToday: Bool) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: digestDate)
        return Button {
            digestDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 5) {
                Text(isToday ? "TODAY" : date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(Theme.sans(9, weight: .semibold))
                    .tracking(0.5)
                Text(date.formatted(.dateTime.day()))
                    .font(Theme.sans(17, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? Theme.onHero : Theme.secondaryInk)
            .frame(width: 54, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.primary : Theme.surfaceSunken)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isToday ? "Today, \(Format.shortDate(date))" : Format.shortDate(date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var roomScope: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Selected rooms")
            HStack(spacing: 8) {
                ForEach(selectedRooms) { room in
                    Pill(text: room.name, systemImage: "square.split.2x2")
                }
            }
            .accessibilityElement(children: .combine)
        }
        .growCard(padding: 14)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                "Care activity",
                subtitle: "\(Format.shortDate(snapshot.activityStart)) · \(snapshot.activityCount) record\(snapshot.activityCount == 1 ? "" : "s")"
            )
            if activityItems.isEmpty {
                emptyCard("No care activity was recorded for this day.", symbol: "leaf")
            } else {
                VStack(spacing: 0) {
                    ForEach(activityItems) { item in
                        activityRow(item)
                        if item.id != activityItems.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private func activityRow(_ item: CareDigestActivityItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: item.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.sageSoft))
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(Format.time(item.date))
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                }
                Text(item.roomName)
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                Text(item.detail)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var unfinishedTasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                "Unfinished scheduled tasks",
                subtitle: "Overdue before \(Format.shortDate(digestDate)) · \(snapshot.unfinishedReminders.count)"
            )
            if snapshot.unfinishedReminders.isEmpty {
                emptyCard("Nothing was overdue when this digest was prepared.", symbol: "checkmark.circle")
            } else {
                VStack(spacing: 0) {
                    ForEach(snapshot.unfinishedReminders) { reminder in
                        reminderRow(reminder)
                        if reminder.persistentModelID != snapshot.unfinishedReminders.last?.persistentModelID {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private func reminderRow(_ reminder: CareReminder) -> some View {
        HStack(spacing: 11) {
            Image(systemName: reminder.kind.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.amber)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.amberSoft))
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.displayTitle)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(reminder.room?.name ?? "Room") · Due \(Format.shortDate(reminder.nextDueDate)) at \(Format.time(reminder.nextDueDate))")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var noRoomsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("No rooms selected")
            Text("Choose rooms in Notifications → Daily care digest to preview their care activity and unfinished tasks.")
                .font(Theme.sans(14))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private func emptyCard(_ text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.primary)
            Text(text)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .growCard(fill: Theme.surface, padding: 15)
    }

    private func feedDetail(_ event: FeedEvent) -> String {
        var details: [String] = []
        if let volume = event.volumeLiters { details.append(Format.volume(volume, unit: unit)) }
        if let ph = event.phIn { details.append(String(format: "pH %.2f", ph)) }
        if let ec = event.ecIn { details.append(String(format: "EC %.2f", ec)) }
        return details.isEmpty ? "Care record saved" : details.joined(separator: " · ")
    }

    private func readingDetail(_ reading: EnvironmentReading) -> String {
        var details: [String] = []
        if let temperature = reading.temperatureC { details.append(Format.temperature(temperature, unit: unit)) }
        if let humidity = reading.humidityPercent { details.append(String(format: "RH %.0f%%", humidity)) }
        if let light = reading.lightPPFD { details.append(String(format: "%.0f PPFD", light)) }
        return details.isEmpty ? "Reading saved" : details.joined(separator: " · ")
    }
}

private struct CareDigestActivityItem: Identifiable {
    let id: String
    let date: Date
    let roomName: String
    let title: String
    let detail: String
    let symbol: String
}
