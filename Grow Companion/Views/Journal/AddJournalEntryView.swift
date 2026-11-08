//
//  AddJournalEntryView.swift
//  Grow Companion
//
//  Photos are re-encoded on import so no GPS or device metadata leaves the
//  camera untouched.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddJournalEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @State private var kind: JournalKind = .note
    @State private var text = ""
    @State private var tag: ObservationTag = .healthy
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var selectedPlant: Plant?
    @State private var selectedRoom: Room?

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool { hasText || imageData != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    kindPicker
                    textSection
                    if kind == .observation { observationSection }
                    photoSection
                    linkSection
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.primary : Theme.tertiaryInk)
                        .disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
    }

    // MARK: Sections

    private var kindPicker: some View {
        Picker("Type", selection: $kind) {
            ForEach(JournalKind.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("What happened")

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 140)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Leaves on the lower nodes are pale, everything else looks fine.")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.tertiaryInk)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var observationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Observation")
            Menu {
                ForEach(ObservationTag.allCases) { option in
                    Button {
                        tag = option
                    } label: {
                        Label(option.title, systemImage: option.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: tag.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    Text(tag.title)
                        .font(Theme.sans(14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.sageSoft)
                )
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Photo")

            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: imageData == nil ? "photo" : "checkmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text(imageData == nil ? "Attach a photo" : "Photo attached")
                            .font(Theme.sans(14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.sageSoft))
                }

                if let data = imageData, let preview = UIImage(data: data) {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button {
                        imageData = nil
                        photoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo")
                }
            }

            Text("Location and device metadata are stripped before the photo is saved.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Link to")

            HStack(spacing: 8) {
                Menu {
                    Button("None") { selectedPlant = nil }
                    ForEach(plants) { plant in
                        Button(plant.displayName) { selectedPlant = plant }
                    }
                } label: {
                    linkChip(
                        title: selectedPlant?.displayName ?? "No plant",
                        symbol: "leaf",
                        isSet: selectedPlant != nil
                    )
                }

                Menu {
                    Button("None") { selectedRoom = nil }
                    ForEach(rooms) { room in
                        Button(room.name) { selectedRoom = room }
                    }
                } label: {
                    linkChip(
                        title: selectedRoom?.name ?? "No room",
                        symbol: "tent",
                        isSet: selectedRoom != nil
                    )
                }
            }
        }
    }

    // MARK: Building blocks

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }

    private func linkChip(title: String, symbol: String, isSet: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(Theme.sans(13, weight: .medium))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(isSet ? Theme.primary : Theme.secondaryInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(isSet ? Theme.sageSoft : Theme.surfaceSunken))
    }

    // MARK: Actions

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    imageData = data
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var fileName: String?
        if let imageData {
            fileName = PhotoStore.save(imageData: imageData)
        }

        guard !trimmed.isEmpty || fileName != nil else { return }

        let resolvedKind: JournalKind = (kind == .photo && fileName == nil) ? .note : kind
        let entry = JournalEntry(
            kind: resolvedKind,
            text: trimmed,
            tag: resolvedKind == .observation ? tag : nil,
            photoFileName: fileName,
            plant: selectedPlant,
            room: selectedRoom
        )
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
