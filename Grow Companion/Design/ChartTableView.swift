//
//  ChartTableView.swift
//  Grow Companion
//
//  The text equivalent of a chart or ring. Every value a chart draws is also
//  listed here, so VoiceOver and a grower who prefers reading numbers never
//  need the picture.
//

import SwiftUI

struct ChartTableRow: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let isFlagged: Bool
}

struct ChartTable: Identifiable, Equatable {
    let id: String
    let title: String
    /// One sentence read as the hint before the rows.
    let summary: String
    let rows: [ChartTableRow]

    var isEmpty: Bool { rows.isEmpty }
}

struct ChartTableDisclosure: View {
    let table: ChartTable

    @State private var isExpanded = false

    var body: some View {
        if !table.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 6) {
                    ForEach(table.rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(row.label)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            Text(row.value)
                                .font(Theme.sans(12, weight: .semibold))
                                .foregroundStyle(row.isFlagged ? Theme.danger : Theme.ink)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(row.label): \(row.value)")
                    }
                }
                .padding(.top, 8)
            } label: {
                Text(table.title)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            .accessibilityHint(table.summary)
        }
    }
}
