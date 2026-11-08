//
//  PlantTrainingSection.swift
//  Grow Companion
//
//  A plant's training history: every session newest first, with its method,
//  how long ago it happened, the nodes affected and the note.
//

import SwiftUI

struct PlantTrainingSection: View {
    let plant: Plant

    @State private var showingEditor = false
    @State private var editingSession: TrainingSession?

    private var sessions: [TrainingSession] {
        plant.sortedTrainingSessions
    }

    private var subtitle: String {
        guard let last = sessions.first else { return "No sessions recorded" }
        let count = sessions.count
        return "\(count) session\(count == 1 ? "" : "s") · last \(TrainingLog.relativeText(last.date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Training", subtitle: subtitle)

            if sessions.isEmpty {
                Text("Top, tie down or defoliate a plant, and the session lands here with its date and how long ago it happened.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        Button {
                            editingSession = session
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)

                        if session.id != sessions.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }

            SecondaryButton("Log training", systemImage: "plus") {
                showingEditor = true
            }
        }
        .growCard()
        .sheet(isPresented: $showingEditor) {
            TrainingSessionEditor(plant: plant)
        }
        .sheet(item: $editingSession) { session in
            TrainingSessionEditor(plant: plant, session: session)
        }
    }

    private func sessionRow(_ session: TrainingSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: session.method.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.method.title)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 6) {
                    Text(TrainingLog.relativeText(session.date))
                    if let nodes = TrainingLog.nodesText(session.nodesAffected) {
                        Text("· \(nodes)")
                    }
                }
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)

                if !session.note.isEmpty {
                    Text(session.note)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.tertiaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 6)

            Text(Format.shortDate(session.date))
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
