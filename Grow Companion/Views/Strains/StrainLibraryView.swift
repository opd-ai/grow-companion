//
//  StrainLibraryView.swift
//  Grow Companion
//
//  The cultivar library: what the breeder expects, what your own finished
//  cycles actually did, and how the harvests were rated.
//

import SwiftUI
import SwiftData

struct StrainLibraryView: View {
    @Query(sort: \Strain.name) private var strains: [Strain]

    @State private var showingEditor = false
    @State private var editingStrain: Strain?

    private var subtitle: String {
        if strains.isEmpty {
            return String(localized: "Breeder figures, your own flowering times and the harvests you rated.")
        }
        return String(localized: "\(strains.count) cultivar\(strains.count == 1 ? "" : "s") on this device")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if strains.isEmpty {
                    emptyState
                } else {
                    strainList
                    SecondaryButton("Add a strain", systemImage: "plus") {
                        startAdding()
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
            addButton
        }
        .sheet(isPresented: $showingEditor) {
            StrainEditorView(strain: editingStrain)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Strains")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var strainList: some View {
        VStack(spacing: 0) {
            ForEach(strains) { strain in
                NavigationLink {
                    StrainDetailView(strain: strain)
                } label: {
                    StrainRow(strain: strain)
                }
                .buttonStyle(.plain)

                if strain.id != strains.last?.id {
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .growCard(padding: 14)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("Start with one strain")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Pick a bundled template or add your own: breeder, type, expected flowering weeks and notes. Assign it to a plant, and once a cycle finishes your observed flowering time takes over from the breeder's figure.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Add a strain", systemImage: "plus") {
                startAdding()
            }
        }
        .growCard()
    }

    private var addButton: some View {
        Button {
            startAdding()
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
        .accessibilityLabel("Add strain")
    }

    private func startAdding() {
        editingStrain = nil
        showingEditor = true
    }
}

struct StrainRow: View {
    let strain: Strain

    private var observed: (days: Double, count: Int)? {
        StrainInsights.observedAverage(for: strain)
    }

    private var detail: String {
        let breeder = strain.breeder.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [strain.type.title, breeder.isEmpty ? "No breeder" : breeder]
        if strain.lineageStatus != .documented { parts.append(strain.lineageStatus.title.lowercased()) }
        if let observed {
            parts.append("yours \(StrainInsights.shortLengthText(days: observed.days))")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.sageSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: strain.type.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(strain.displayName)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                if let rating = strain.averageRating {
                    StarRatingView(rating: Int(rating.rounded()), size: 10)
                }
                Text(strain.floweringLabel)
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
