//
//  JournalEntryDetailView.swift
//  Grow Companion
//
//  One journal entry with its photo and the records it links to.
//

import SwiftUI
import SwiftData
import UIKit

struct JournalEntryDetailView: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                JournalEntryCard(entry: entry)

                if let fileName = entry.photoFileName,
                   let image = PhotoStore.thumbnail(named: fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityLabel("Journal photo")
                }

                if entry.plant != nil || entry.room != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Linked records")
                        if let plant = entry.plant {
                            NavigationLink {
                                PlantDetailView(plant: plant)
                            } label: {
                                linkedRow(title: plant.displayName, symbol: "leaf")
                            }
                            .buttonStyle(.plain)
                        }
                        if let room = entry.room {
                            NavigationLink {
                                RoomDetailView(room: room)
                            } label: {
                                linkedRow(title: room.name, symbol: room.type.systemImage)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .growCard(padding: 16)
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Journal entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func linkedRow(title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 22)
            Text(title)
                .font(Theme.sans(14, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
