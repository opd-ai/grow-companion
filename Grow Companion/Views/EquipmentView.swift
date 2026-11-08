//
//  EquipmentView.swift
//  Grow Companion
//
//  Room-by-room equipment list with service reminders.
//

import SwiftUI
import SwiftData

struct EquipmentView: View {
    @Query(sort: \Equipment.name) private var equipment: [Equipment]
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var roomFilter: PersistentIdentifier?
    @State private var dueFilter: DueFilter = .all
    @State private var showingEditor = false
    @State private var editingEquipment: Equipment?
    @State private var selectedEquipment: Equipment?
    @State private var loggingEquipment: Equipment?

    private enum DueFilter: String, CaseIterable, Identifiable {
        case all, dueSoon, overdue
        var id: String { rawValue }
        var title: String {
            switch self { case .all: return String(localized: "All"); case .dueSoon: return String(localized: "Due soon"); case .overdue: return String(localized: "Overdue") }
        }
    }

    private var filteredEquipment: [Equipment] {
        equipment.filter { item in
            let roomMatches = roomFilter == nil || item.room?.persistentModelID == roomFilter
            let dueMatches: Bool
            switch dueFilter {
            case .all: dueMatches = true
            case .dueSoon: dueMatches = !item.isOverdue && item.daysUntilService <= 30
            case .overdue: dueMatches = item.isOverdue
            }
            return roomMatches && dueMatches
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                roomFilters
                dueFilters
                if filteredEquipment.isEmpty { emptyState } else { equipmentList }
                addButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingEditor) { EquipmentEditor() }
        .sheet(item: $editingEquipment) { item in EquipmentEditor(equipment: item) }
        .sheet(item: $selectedEquipment) { item in
            NavigationStack { EquipmentDetailView(equipment: item) }
        }
        .sheet(item: $loggingEquipment) { item in ServiceLogEditor(equipment: item) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Equipment")
                .font(Theme.serif(42))
                .foregroundStyle(Theme.ink)
            Text("What keeps the grow running.")
                .font(Theme.sans(22))
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 8)
    }

    private var roomFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip("All rooms", selected: roomFilter == nil) { roomFilter = nil }
                ForEach(rooms, id: \.persistentModelID) { room in
                    filterChip(room.name, selected: roomFilter == room.persistentModelID) {
                        roomFilter = room.persistentModelID
                    }
                }
            }
        }
    }

    private var dueFilters: some View {
        HStack(spacing: 10) {
            ForEach(DueFilter.allCases) { filter in
                filterChip(filter.title, selected: dueFilter == filter) { dueFilter = filter }
            }
            Spacer(minLength: 0)
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(16, weight: .medium))
                .foregroundStyle(selected ? Theme.onHero : Theme.secondaryInk)
                .padding(.horizontal, 19)
                .padding(.vertical, 13)
                .background(Capsule().fill(selected ? Theme.primary : Theme.surfaceSunken))
        }
        .buttonStyle(.plain)
    }

    private var equipmentList: some View {
        VStack(spacing: 12) {
            ForEach(filteredEquipment) { item in equipmentCard(item) }
        }
    }

    private func equipmentCard(_ item: Equipment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(Theme.sageSoft).frame(width: 58, height: 58)
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.primary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text("\(item.room?.name ?? "No room") · \(EquipmentLog.intervalText(item.serviceIntervalDays))")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                    Text("Last serviced \(Format.shortDate(item.lastServicedAt)) · next \(Format.shortDate(item.nextServiceDate))")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
            }

            HStack {
                Spacer(minLength: 72)
                Text(EquipmentLog.dueText(for: item))
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(item.isOverdue ? Theme.amber : Theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(item.isOverdue ? Theme.amberSoft : Theme.sageSoft))
                Button("Log service") { loggingEquipment = item }
                    .font(Theme.sans(14, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .buttonStyle(.plain)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
            }
            .padding(.top, 10)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { selectedEquipment = item }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .padding(24)
                .background(Circle().fill(Theme.sageSoft))
            Text("No equipment yet")
                .font(Theme.sans(19, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Add the light, fan or pump that keeps your grow running smoothly.")
                .font(Theme.sans(15))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private var addButton: some View {
        SecondaryButton("Add equipment", systemImage: "plus") { showingEditor = true }
    }
}
