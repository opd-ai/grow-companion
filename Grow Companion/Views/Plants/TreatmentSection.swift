//
//  TreatmentSection.swift
//  Grow Companion
//
//  Treatment history and active withdrawal status for a plant.
//

import SwiftUI

struct TreatmentSection: View {
    let plant: Plant

    @State private var showingEditor = false
    @State private var editingTreatment: Treatment?

    private var treatments: [Treatment] { plant.allTreatments.sorted { $0.date > $1.date } }
    private var activeTreatment: Treatment? { TreatmentLog.activeWithdrawal(for: plant) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Treatments", subtitle: treatments.isEmpty ? "No treatments recorded" : "\(treatments.count) record\(treatments.count == 1 ? "" : "s")")

            if let activeTreatment, let endDate = activeTreatment.withdrawalEndDate {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Withdrawal active")
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Ends \(Format.shortDate(endDate)) · \(activeTreatment.productName)")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.amberSoft))
            }

            if treatments.isEmpty {
                Text("Record a product, dose, date and any withdrawal period. The app keeps your history without recommending products.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(treatments) { treatment in
                        Button { editingTreatment = treatment } label: {
                            treatmentRow(treatment)
                        }
                        .buttonStyle(.plain)
                        if treatment.id != treatments.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
            }

            SecondaryButton("Log treatment", systemImage: "plus") { showingEditor = true }
        }
        .growCard()
        .sheet(isPresented: $showingEditor) { TreatmentEditor(plant: plant, room: nil) }
        .sheet(item: $editingTreatment) { treatment in TreatmentEditor(plant: plant, room: treatment.room, treatment: treatment) }
    }

    private func treatmentRow(_ treatment: Treatment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(treatment.isWithdrawalActive ? Theme.amberSoft : Theme.sageSoft).frame(width: 32, height: 32)
                Image(systemName: treatment.isWithdrawalActive ? "flag.fill" : "spraycan").font(.system(size: 13, weight: .semibold)).foregroundStyle(treatment.isWithdrawalActive ? Theme.amber : Theme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(treatment.productName).font(Theme.sans(14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text([treatment.dose, Format.shortDate(treatment.date)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                if let withdrawal = treatment.withdrawalEndDate {
                    Text("Withdrawal ends \(Format.shortDate(withdrawal))").font(Theme.sans(12)).foregroundStyle(treatment.isWithdrawalActive ? Theme.amber : Theme.tertiaryInk)
                }
                if !treatment.note.isEmpty { Text(treatment.note).font(Theme.sans(12)).foregroundStyle(Theme.tertiaryInk).lineLimit(2) }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
