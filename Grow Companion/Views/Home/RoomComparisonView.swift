//
//  RoomComparisonView.swift
//  Grow Companion
//
//  Read-only comparison of two rooms over a chosen date range.
//

import SwiftUI
import SwiftData

struct RoomComparisonView: View {
    @Query(sort: \Room.name) private var rooms: [Room]
    @State private var leftRoomName = ""
    @State private var rightRoomName = ""
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()

    private var leftRoom: Room? { rooms.first { $0.name == leftRoomName } }
    private var rightRoom: Room? { rooms.first { $0.name == rightRoomName } }
    private var hasTwoRooms: Bool { rooms.count >= 2 && leftRoom != nil && rightRoom != nil && leftRoomName != rightRoomName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                selectors
                if hasTwoRooms, let leftRoom, let rightRoom {
                    comparison(leftRoom, rightRoom)
                } else {
                    emptyState
                }
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Room comparison")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if leftRoomName.isEmpty { leftRoomName = rooms.first?.name ?? "" }
            if rightRoomName.isEmpty { rightRoomName = rooms.dropFirst().first?.name ?? "" }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compare rooms")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("A read-only view of the records you already keep.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var selectors: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                roomPicker("Room 1", selection: $leftRoomName)
                roomPicker("Room 2", selection: $rightRoomName)
            }
            HStack {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }
            .font(Theme.sans(13))
            .tint(Theme.primary)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14)
    }

    private func roomPicker(_ title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Theme.sans(10, weight: .semibold)).textCase(.uppercase).foregroundStyle(Theme.secondaryInk)
            Picker(title, selection: selection) {
                ForEach(rooms) { room in Text(room.name).tag(room.name) }
            }
            .labelsHidden()
            .tint(Theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparison(_ left: Room, _ right: Room) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(Format.shortDate(startDate)) – \(Format.shortDate(endDate))")
                    .font(Theme.sans(12, weight: .medium)).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Text("No values are inferred")
                    .font(Theme.sans(11)).foregroundStyle(Theme.tertiaryInk)
            }
            VStack(spacing: 0) {
                metricRow("Plants", leftValue: plantCount(in: left), rightValue: plantCount(in: right))
                divider
                metricRow("Readings out of range", leftValue: outOfRangeCount(in: left), rightValue: outOfRangeCount(in: right))
                divider
                metricRow("Feeds & waterings", leftValue: feedCount(in: left), rightValue: feedCount(in: right))
                divider
                metricRow("Training sessions", leftValue: trainingCount(in: left), rightValue: trainingCount(in: right))
                divider
                metricRow("Dry yield", leftValue: dryYield(in: left), rightValue: dryYield(in: right))
                divider
                metricRow("Grams per watt", leftValue: gramsPerWatt(in: left), rightValue: gramsPerWatt(in: right))
            }
            .growCard(padding: 16)
        }
    }

    private var divider: some View { Divider().overlay(Theme.hairline) }

    private func metricRow(_ title: String, leftValue: String, rightValue: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.sans(13, weight: .semibold)).foregroundStyle(Theme.secondaryInk)
                Text(leftValue).font(Theme.serif(22)).foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(Theme.hairline)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.sans(13, weight: .semibold)).foregroundStyle(Theme.secondaryInk).opacity(0)
                Text(rightValue).font(Theme.serif(22)).foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(leftValue) for \(leftRoomName), \(rightValue) for \(rightRoomName)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 24, weight: .medium)).foregroundStyle(Theme.primary)
            Text(rooms.count < 2 ? "Add another room to compare performance." : "Choose two different rooms to compare.")
                .font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("The report only reads existing records and never fills in missing values.")
                .font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
        }
        .growCard(fill: Theme.sageSoft, padding: 18)
    }

    private func inRange(_ date: Date) -> Bool { date >= startDate && date <= endDate }

    private func plantCount(in room: Room) -> String {
        let count = room.plants.filter { inRange($0.plantedAt) || ($0.harvestedAt.map(inRange) ?? false) }.count
        return count == 0 ? "No data" : "\(count)"
    }

    private func outOfRangeCount(in room: Room) -> String {
        let count = room.environmentReadings.filter { inRange($0.date) && $0.isAnyOutOfRange }.count
        return count == 0 ? "0" : "\(count)"
    }

    private func feedCount(in room: Room) -> String {
        let count = room.feedEvents.filter { inRange($0.date) }.count
        return count == 0 ? "0" : "\(count)"
    }

    private func trainingCount(in room: Room) -> String {
        let count = room.plants.flatMap(\.trainingSessions).filter { inRange($0.date) }.count
        return count == 0 ? "0" : "\(count)"
    }

    private func dryYield(in room: Room) -> String {
        let values = room.plants.filter { $0.harvestedAt.map(inRange) ?? false }.compactMap(\.dryWeightGrams)
        guard !values.isEmpty else { return String(localized: "No data") }
        return Format.weight(values.reduce(0, +), unit: .metric)
    }

    private func gramsPerWatt(in room: Room) -> String {
        let values = room.plants.filter { $0.harvestedAt.map(inRange) ?? false }
            .compactMap { HarvestLog.gramsPerWatt(dryGrams: $0.dryWeightGrams, watts: room.lightWatts) }
        guard !values.isEmpty else { return String(localized: "No data") }
        return String(format: "%.2f g/W", values.reduce(0, +) / Double(values.count))
    }
}
