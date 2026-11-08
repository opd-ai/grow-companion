//
//  JournalView.swift
//  Grow Companion
//
//  A timestamped timeline of notes, observations and photos, grouped by day
//  and linked to plants and rooms.
//

import SwiftUI
import SwiftData
import UIKit

struct JournalView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @State private var showingAdd = false
    @State private var selectedRoom: Room?

    private var filteredEntries: [JournalEntry] {
        guard let selectedRoom else { return entries }
        return entries.filter { entry in
            entry.room?.persistentModelID == selectedRoom.persistentModelID
                || entry.plant?.room?.persistentModelID == selectedRoom.persistentModelID
        }
    }

    private var sections: [(day: Date, entries: [JournalEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { calendar.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { key in
            let dayEntries = (groups[key] ?? []).sorted { $0.createdAt > $1.createdAt }
            return (key, dayEntries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Journal")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text(entries.isEmpty ? "Photos and notes build the record you learn from." : "\(entries.count) entr\(entries.count == 1 ? "y" : "ies") on this device")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                }

                if !rooms.isEmpty {
                    RoomFilterChips(rooms: rooms, selectedRoom: $selectedRoom)
                }

                if filteredEntries.isEmpty {
                    if entries.isEmpty {
                        emptyState
                    } else {
                        Text("No journal entries for this room yet.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .growCard(padding: 16)
                    }
                } else {
                    ForEach(sections, id: \.day) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(dayTitle(section.day))
                            ForEach(section.entries) { entry in
                                JournalEntryCard(entry: entry)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Theme.onHero)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Theme.primary))
                    .shadow(color: Theme.ink.opacity(0.18), radius: 12, y: 6)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 20)
            .accessibilityLabel("Add journal entry")
        }
        .sheet(isPresented: $showingAdd) {
            AddJournalEntryView()
        }
        .onChange(of: rooms) { _, newRooms in
            guard let current = selectedRoom else { return }
            if !newRooms.contains(where: { $0 === current }) {
                selectedRoom = nil
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("Start with one line")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("A photo of a leaf and a sentence about what you did today is enough. Timestamps make it possible to see cause and effect later.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Add a journal entry", systemImage: "square.and.pencil") {
                showingAdd = true
            }
        }
        .growCard()
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Format.shortDate(date)
    }
}

struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: entry.kind.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text(entry.kind.title)
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Text(Format.time(entry.createdAt))
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            }

            if let tag = entry.tag {
                Pill(text: tag.title, systemImage: tag.systemImage)
            }

            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let fileName = entry.photoFileName, let image = PhotoStore.thumbnail(named: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Journal photo")
            }

            if entry.plant != nil || entry.room != nil {
                HStack(spacing: 6) {
                    if let plant = entry.plant {
                        Pill(text: plant.displayName, systemImage: "leaf", tint: Theme.secondaryInk, fill: Theme.surfaceSunken)
                    }
                    if let room = entry.room {
                        Pill(text: room.name, systemImage: room.type.systemImage, tint: Theme.secondaryInk, fill: Theme.surfaceSunken)
                    }
                }
            }
        }
        .growCard(padding: 16)
    }
}
