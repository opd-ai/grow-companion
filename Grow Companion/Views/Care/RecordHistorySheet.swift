//
//  RecordHistorySheet.swift
//  Grow Companion
//
//  The whole history behind a "See all" link on a room dashboard, so a record
//  list is never limited to the few rows the dashboard has room for. Read-only:
//  nothing here writes to the store.
//

import SwiftUI

struct RecordHistorySheet<Rows: View>: View {
    let title: String
    let subtitle: String
    let emptyMessage: String
    let recordCount: Int
    private let rows: () -> Rows

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        subtitle: String,
        emptyMessage: String,
        recordCount: Int,
        @ViewBuilder rows: @escaping () -> Rows
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emptyMessage = emptyMessage
        self.recordCount = recordCount
        self.rows = rows
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(Theme.serif(26))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if recordCount == 0 {
                        Text(emptyMessage)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .growCard(padding: 16)
                    } else {
                        VStack(spacing: 0) {
                            rows()
                        }
                        .growCard(padding: 14)
                    }

                    Text("Newest first. Every record here stays on this device.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }
}

/// The "See all" link the dashboards share, so the affordance reads the same
/// everywhere: how many records there are, and that tapping opens them.
struct SeeAllRecordsLink: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("See all \(count) records")
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(Theme.sans(12, weight: .semibold))
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the full list, newest first")
    }
}
