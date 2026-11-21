//
//  LabResultSection.swift
//  Grow Companion
//
//  The lab reports recorded against one plant: what the report printed, kept
//  with the harvest it belongs to. The app never interprets a figure.
//

import SwiftUI

struct LabResultSection: View {
    let plant: Plant

    @State private var showingEditor = false
    @State private var editingResult: LabResult?

    private var results: [LabResult] { LabResultService.sorted(plant.labResults) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Lab reports",
                subtitle: results.isEmpty
                    ? String(localized: "None recorded")
                    : String(localized: "\(results.count) report\(results.count == 1 ? "" : "s")")
            )

            if results.isEmpty {
                Text("If you had a sample tested, type the figures here and they stay with this plant. The app stores what the report printed and never interprets it.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            editingResult = result
                        } label: {
                            row(result)
                        }
                        .buttonStyle(.plain)

                        if result.id != results.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }

            SecondaryButton("Add a lab report", systemImage: "plus") {
                showingEditor = true
            }
        }
        .growCard()
        .sheet(isPresented: $showingEditor) {
            LabResultEditor(plant: plant)
        }
        .sheet(item: $editingResult) { result in
            LabResultEditor(plant: plant, result: result)
        }
    }

    private func row(_ result: LabResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 6) {
                    Text(Format.shortDate(result.reportDate))
                    Text("·")
                    Text("\(result.analytes.count) figure\(result.analytes.count == 1 ? "" : "s")")
                }
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)

                if !result.flaggedAnalytes.isEmpty {
                    Text("The report flags \(result.flaggedAnalytes.count) of them")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
