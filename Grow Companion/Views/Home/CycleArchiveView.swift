//
//  CycleArchiveView.swift
//  Grow Companion
//
//  Completed grow cycles kept separately without deleting their records.
//

import SwiftUI
import SwiftData

struct CycleArchiveView: View {
    @Query(sort: \CycleArchive.completedAt, order: .reverse) private var cycles: [CycleArchive]
    @State private var filter: ArchiveFilter = .all
    @State private var showingEditor = false
    @State private var selectedCycle: CycleArchive?

    private enum ArchiveFilter: String, CaseIterable, Identifiable {
        case all, thisYear, withYield
        var id: String { rawValue }
        var title: String {
            switch self { case .all: return String(localized: "All cycles"); case .thisYear: return String(localized: "This year"); case .withYield: return String(localized: "With yield") }
        }
    }

    private var filteredCycles: [CycleArchive] {
        let year = Calendar.current.component(.year, from: Date())
        return cycles.filter { cycle in
            switch filter {
            case .all: return true
            case .thisYear: return Calendar.current.component(.year, from: cycle.completedAt) == year
            case .withYield: return cycle.dryYieldGrams != nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                filters
                if filteredCycles.isEmpty { emptyState } else { cycleList }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingEditor) { CycleArchiveEditor() }
        .sheet(item: $selectedCycle) { cycle in
            NavigationStack { CycleArchiveDetailView(cycle: cycle) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Cycle archive").font(Theme.serif(42)).foregroundStyle(Theme.ink)
            Text("Finished records, kept close.").font(Theme.sans(22)).foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 8)
    }

    private var filters: some View {
        HStack(spacing: 0) {
            ForEach(ArchiveFilter.allCases) { option in
                Button { filter = option } label: {
                    Text(option.title)
                        .font(Theme.sans(15, weight: .medium))
                        .foregroundStyle(filter == option ? Theme.onHero : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(filter == option ? Theme.primary : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var cycleList: some View {
        VStack(spacing: 12) {
            ForEach(filteredCycles) { cycle in
                Button { selectedCycle = cycle } label: { cycleCard(cycle) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func cycleCard(_ cycle: CycleArchive) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Theme.primary)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.sageSoft))
            VStack(alignment: .leading, spacing: 5) {
                Text(cycle.name).font(Theme.sans(18, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("\(cycle.roomSummary) · \(cycle.plants.count) plant\(cycle.plants.count == 1 ? "" : "s")")
                    .font(Theme.sans(14)).foregroundStyle(Theme.secondaryInk)
                Text("completed \(Format.shortDate(cycle.completedAt))")
                    .font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 4) {
                if let yield = cycle.dryYieldGrams {
                    Text(Format.weight(yield, unit: .metric)).font(Theme.sans(17, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("dry").font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                } else {
                    Text("No dry").font(Theme.sans(13, weight: .semibold)).foregroundStyle(Theme.amber)
                    Text("weight yet").font(Theme.sans(13)).foregroundStyle(Theme.amber)
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.primary)
                .padding(28)
                .background(Circle().fill(Theme.sageSoft))
            Text("No completed cycles yet").font(Theme.serif(25)).foregroundStyle(Theme.ink)
            Text("Finish a plant cycle to keep its full record here.")
                .font(Theme.sans(15)).foregroundStyle(Theme.secondaryInk).multilineTextAlignment(.center)
            SecondaryButton("Archive completed plants", systemImage: "plus") { showingEditor = true }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
