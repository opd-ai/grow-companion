//
//  EquipmentDetailView.swift
//  Grow Companion
//
//  Equipment details and recent service history.
//

import SwiftUI

struct EquipmentDetailView: View {
    @Bindable var equipment: Equipment

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var showingServiceLog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(equipment.name)
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text("\(equipment.room?.name ?? "No room") · \(EquipmentLog.intervalText(equipment.serviceIntervalDays))")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                    HStack {
                        Text(EquipmentLog.dueText(for: equipment))
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(equipment.isOverdue ? Theme.amber : Theme.primary)
                        Spacer()
                        Text("Next \(Format.shortDate(equipment.nextServiceDate))")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(equipment.isOverdue ? Theme.amberSoft : Theme.sageSoft))
                }
                .growCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Service history", subtitle: equipment.sortedServiceRecords.isEmpty ? "No services recorded" : "Recent services")
                    if equipment.sortedServiceRecords.isEmpty {
                        Text("Completed service dates and notes will stay here.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    } else {
                        ForEach(equipment.sortedServiceRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Format.shortDate(record.date))
                                    .font(Theme.sans(14, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                if !record.note.isEmpty {
                                    Text(record.note)
                                        .font(Theme.sans(13))
                                        .foregroundStyle(Theme.secondaryInk)
                                } else {
                                    Text("Service completed")
                                        .font(Theme.sans(13))
                                        .foregroundStyle(Theme.tertiaryInk)
                                }
                            }
                            .padding(.vertical, 8)
                            if record.id != equipment.sortedServiceRecords.last?.id {
                                Divider().overlay(Theme.hairline)
                            }
                        }
                    }
                    SecondaryButton("Log service", systemImage: "checkmark") { showingServiceLog = true }
                }
                .growCard()
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
                    .foregroundStyle(Theme.primary)
            }
        }
        .sheet(isPresented: $showingEditor) { EquipmentEditor(equipment: equipment) }
        .sheet(isPresented: $showingServiceLog) { ServiceLogEditor(equipment: equipment) }
    }
}
