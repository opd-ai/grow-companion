//
//  FeedTargetSheet.swift
//  Grow Companion
//
//  The reservoir or feed-plan target the feed log compares against.
//

import SwiftUI
import SwiftData

struct FeedTargetSheet: View {
    let room: Room

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var phText = ""
    @State private var ecText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Feeding target")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("The pH and EC you aim for in \(room.name)'s reservoir. Feed and runoff readings are compared with these.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Target pH")
                        CareInput.field(placeholder: "6.2", text: $phText)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Target EC (mS/cm)")
                        CareInput.field(placeholder: "1.60", text: $ecText)
                    }

                    PrimaryButton("Save target", systemImage: "checkmark") {
                        save()
                    }

                    if room.feedTargetPH != nil || room.feedTargetEC != nil {
                        Button {
                            room.feedTargetPH = nil
                            room.feedTargetEC = nil
                            try? context.save()
                            dismiss()
                        } label: {
                            Text("Clear target")
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .onAppear {
            phText = room.feedTargetPH.map { String(format: "%.1f", $0) } ?? ""
            ecText = room.feedTargetEC.map { String(format: "%.2f", $0) } ?? ""
        }
    }

    private func save() {
        room.feedTargetPH = CareInput.number(phText)
        room.feedTargetEC = CareInput.number(ecText)
        try? context.save()
        dismiss()
    }
}
