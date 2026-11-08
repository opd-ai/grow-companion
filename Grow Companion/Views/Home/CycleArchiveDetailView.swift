import SwiftUI

struct CycleArchiveDetailView: View {
    let cycle: CycleArchive
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingReopen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(cycle.name).font(Theme.serif(30)).foregroundStyle(Theme.ink)
                    Text("\(cycle.roomSummary) · completed \(Format.shortDate(cycle.completedAt))")
                        .font(Theme.sans(14)).foregroundStyle(Theme.secondaryInk)
                }
                .growCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Preserved plants", subtitle: "Their full records remain unchanged")
                    ForEach(cycle.sortedPlants) { plant in
                        NavigationLink { PlantDetailView(plant: plant) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(plant.displayName).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text("\(plant.stage.title) · \(plant.displayStrain)").font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.tertiaryInk)
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                    if let yield = cycle.dryYieldGrams {
                        InfoRow(label: "Dry yield", value: Format.weight(yield, unit: .metric))
                    } else {
                        InfoRow(label: "Dry yield", value: "Not recorded yet")
                    }
                }
                .growCard()

                SecondaryButton("Reopen cycle", systemImage: "arrow.uturn.backward") { showingReopen = true }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Cycle archive")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reopen this cycle?", isPresented: $showingReopen, titleVisibility: .visible) {
            Button("Reopen cycle", role: .destructive) {
                for plant in cycle.plants { plant.cycleArchive = nil }
                context.delete(cycle)
                try? context.save()
                dismiss()
            }
            Button("Keep archived", role: .cancel) {}
        } message: {
            Text("The plants return to your active records. Their stage, feed, environment, journal, treatment and yield history stay intact.")
        }
    }
}
