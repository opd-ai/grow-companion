//
//  EquipmentDetailView.swift
//  Grow Companion
//
//  Equipment details, its service history and removal. A service on record can
//  be opened, corrected or removed; removing the item takes its history with it.
//

import SwiftUI
import SwiftData

struct EquipmentDetailView: View {
    @Bindable var equipment: Equipment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditor = false
    @State private var showingServiceLog = false
    @State private var editingRecord: ServiceRecord?
    @State private var showingDelete = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var records: [ServiceRecord] { equipment.sortedServiceRecords }

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
                    SectionHeader("Service history", subtitle: records.isEmpty ? "No services recorded" : "Recent services")
                    if records.isEmpty {
                        Text("Completed service dates and notes will stay here.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    } else {
                        ForEach(records) { record in
                            Button {
                                editingRecord = record
                            } label: {
                                ServiceRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens this service so you can change or remove it.")

                            if record.id != records.last?.id {
                                Divider().overlay(Theme.hairline)
                            }
                        }
                    }
                    SecondaryButton("Log service", systemImage: "checkmark") { showingServiceLog = true }
                }
                .growCard()

                deleteButton
            }
            .padding(20)
            .padding(.bottom, 12)
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
        .sheet(isPresented: $showingServiceLog) { ServiceRecordEditor(equipment: equipment) }
        .sheet(item: $editingRecord) { record in
            ServiceRecordEditor(equipment: equipment, record: record)
        }
        .confirmationDialog(
            String(localized: "Delete \(equipment.name)?"),
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete equipment", role: .destructive) { deleteEquipment() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(deletionMessage)
        }
        .alert("Could not delete", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var recordCount: Int {
        EquipmentService.summary(for: equipment).serviceRecords
    }

    private var deletionMessage: String {
        switch recordCount {
        case 0:
            return String(localized: "The item leaves your equipment list. Nothing else in your grow is changed.")
        case 1:
            return String(localized: "The item and its 1 service record leave your equipment list. Nothing else in your grow is changed.")
        default:
            return String(localized: "The item and its \(recordCount) service records leave your equipment list. Nothing else in your grow is changed.")
        }
    }

    private var deleteButton: some View {
        Button {
            showingDelete = true
        } label: {
            Text("Delete equipment")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func deleteEquipment() {
        do {
            try EquipmentService.delete(equipment, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Record row

private struct ServiceRecordRow: View {
    let record: ServiceRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
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

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
