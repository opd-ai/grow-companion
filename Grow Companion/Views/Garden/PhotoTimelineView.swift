//
//  PhotoTimelineView.swift
//  Grow Companion
//
//  A photo strip for a plant or room, and a full screen where two photos can be
//  compared side by side with their dates and stages.
//

import SwiftUI
import SwiftData
import UIKit

struct PhotoTimelineStrip: View {
    let photos: [PlantPhoto]
    let onSelect: (PlantPhoto) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(photos) { photo in
                    Button {
                        onSelect(photo)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            photoThumbnail(photo)
                                .frame(width: 92, height: 92)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(photo.dateLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(photo.stageLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.secondaryInk)
                                .lineLimit(1)
                        }
                        .frame(width: 92, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo from \(photo.dateLabel), \(photo.stageLabel)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ photo: PlantPhoto) -> some View {
        if let image = PhotoStore.thumbnail(named: photo.fileName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Theme.surfaceSunken
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
    }
}

struct PhotoTimelineView: View {
    let title: String
    let photos: [PlantPhoto]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: [String] = []

    private var selectedPhotos: [PlantPhoto] {
        selectedIDs.compactMap { id in
            photos.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if photos.isEmpty {
                        emptyState
                    } else {
                        compareCard
                        photoGrid
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("\(photos.count) photo\(photos.count == 1 ? "" : "s") in date order. Pick two to compare them side by side.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No photos yet")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Photos attached to journal entries appear here. They are stored in the app's protected photo folder with location metadata removed.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader("Compare")
                Spacer()
                if !selectedIDs.isEmpty {
                    Button("Clear") { selectedIDs = [] }
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                compareColumn(photo: selectedAt(0), label: "First")
                compareColumn(photo: selectedAt(1), label: "Second")
            }

            if selectedPhotos.isEmpty {
                Text("Select two photos below.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
            } else if selectedPhotos.count == 1 {
                Text("Select one more photo to compare.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .growCard(padding: 16)
    }

    private func selectedAt(_ index: Int) -> PlantPhoto? {
        guard selectedPhotos.indices.contains(index) else { return nil }
        return selectedPhotos[index]
    }

    private func compareColumn(photo: PlantPhoto?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let photo, let image = PhotoStore.image(named: photo.fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .background(Theme.surfaceSunken)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceSunken)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                }
                .frame(height: 170)
            }

            Text(photo?.dateLabel ?? "\(label) photo")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(photo?.stageLabel ?? "Stage not recorded")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryInk)

            if let photo {
                Text(photo.plantName ?? photo.roomName ?? "No linked record")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiaryInk)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(label) photo, \(photo?.dateLabel ?? "none selected"), \(photo?.stageLabel ?? "")"
        )
    }

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("All photos")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(photos) { photo in
                    Button {
                        toggle(photo)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            if let image = PhotoStore.thumbnail(named: photo.fileName) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 108)
                                    .clipped()
                            } else {
                                Theme.surfaceSunken
                                    .frame(height: 108)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(Theme.tertiaryInk)
                                    }
                            }

                            if let index = selectedIDs.firstIndex(of: photo.id) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.onHero)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Theme.primary))
                                    .padding(6)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "Photo from \(photo.dateLabel), \(photo.stageLabel)"
                    )
                    .accessibilityValue(
                        selectedIDs.firstIndex(of: photo.id).map { "Selected number \($0 + 1)" } ?? "Not selected"
                    )
                }
            }
        }
    }

    private func toggle(_ photo: PlantPhoto) {
        if let index = selectedIDs.firstIndex(of: photo.id) {
            selectedIDs.remove(at: index)
            return
        }
        if selectedIDs.count >= 2 {
            selectedIDs.removeFirst()
        }
        selectedIDs.append(photo.id)
    }
}
