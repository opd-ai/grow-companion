//
//  MotherPlantPickerSheet.swift
//  Grow Companion
//
//  Pick or clear the mother a clone or cutting came from.
//

import SwiftUI

struct MotherPlantPickerSheet: View {
    let plant: Plant
    let candidates: [Plant]
    let onSelect: (Plant?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pick the plant this cutting came from. The generation number follows the mother.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        optionRow(
                            title: "No mother plant",
                            subtitle: "Clear the lineage",
                            systemImage: "minus.circle",
                            isSelected: plant.mother == nil
                        ) {
                            onSelect(nil)
                            dismiss()
                        }

                        ForEach(candidates) { candidate in
                            Divider().overlay(Theme.hairline)

                            optionRow(
                                title: candidate.displayName,
                                subtitle: "\(candidate.displayStrain) · Generation \(candidate.generation)",
                                systemImage: candidate.stage.systemImage,
                                isSelected: plant.mother?.persistentModelID == candidate.persistentModelID
                            ) {
                                onSelect(candidate)
                                dismiss()
                            }
                        }
                    }
                    .growCard(padding: 14)

                    if candidates.isEmpty {
                        Text("No other plants to pick from yet.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .growCard(padding: 16)
                    }
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Mother plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func optionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.sageSoft)
                        .frame(width: 32, height: 32)
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
