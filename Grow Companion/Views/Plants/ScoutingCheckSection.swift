//
//  ScoutingCheckSection.swift
//  Grow Companion
//
//  Newest-first scouting history for a plant or room.
//

import SwiftUI

struct ScoutingCheckSection: View {
    let plant: Plant?
    let room: Room?

    @State private var showingEditor = false
    @State private var editingCheck: ScoutingCheck?

    private var checks: [ScoutingCheck] {
        (plant?.scoutingChecks ?? room?.scoutingChecks ?? []).sorted { $0.date > $1.date }
    }
    private var targetName: String { plant?.displayName ?? room?.name ?? "this grow" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Scouting", subtitle: checks.isEmpty ? "No checks recorded" : "\(checks.count) check\(checks.count == 1 ? "" : "s")")
            if checks.isEmpty {
                Text("Record what you see on \(targetName): findings, a note or a photo.")
                    .font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(checks) { check in
                        Button { editingCheck = check } label: { checkRow(check) }
                            .buttonStyle(.plain)
                        if check.id != checks.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
            }
            SecondaryButton("Log scouting check", systemImage: "plus") { showingEditor = true }
        }
        .growCard()
        .sheet(isPresented: $showingEditor) { ScoutingCheckEditor(plant: plant, room: room) }
        .sheet(item: $editingCheck) { check in ScoutingCheckEditor(plant: plant, room: room, check: check) }
    }

    private func checkRow(_ check: ScoutingCheck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Theme.sageSoft).frame(width: 32, height: 32)
                Image(systemName: check.findings.first?.systemImage ?? "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(check.findings.map(\.title).joined(separator: " · ").isEmpty ? "General check" : check.findings.map(\.title).joined(separator: " · "))
                    .font(Theme.sans(14, weight: .semibold)).foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text(Format.shortDate(check.date))
                    if check.photoFileName != nil { Text("·"); Image(systemName: "photo") }
                }
                .font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                if !check.note.isEmpty { Text(check.note).font(Theme.sans(12)).foregroundStyle(Theme.tertiaryInk).lineLimit(2) }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
