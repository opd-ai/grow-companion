//
//  CreateShareView.swift
//  Grow Companion
//
//  Picks a scope, seals it for one recipient's share code and hands the file to
//  the system share sheet. No account, server or upload is involved.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CreateShareView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let source: SharePayloadBuilder.Source
    let onShared: () -> Void

    @State private var recipientLabel = ""
    @State private var recipientCode = ""
    @State private var selectedRooms: Set<String> = []
    @State private var selectedPlants: Set<String> = []
    @State private var selectedCategories: Set<ShareCategory> = [.plantRecords, .environment]
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var prepared: SharePackageService.PreparedShare?
    @State private var exportDocument: ExportDocument?
    @State private var showingExporter = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private let service = SharePackageService()

    private var roomNames: [String] {
        source.rooms.map(\.name).sorted()
    }

    private var plantNames: [String] {
        source.plants.map(\.displayName).sorted()
    }

    private var canPrepare: Bool {
        !recipientLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ShareCode.isValid(recipientCode)
            && !(selectedRooms.isEmpty && selectedPlants.isEmpty)
            && !selectedCategories.isEmpty
            && expiresAt > Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    recipientCard
                    scopeCard
                    categoryCard
                    expiryCard

                    PrimaryButton("Prepare protected share", systemImage: "lock.rectangle", isEnabled: canPrepare) {
                        prepare()
                    }

                    Text("The file is encrypted for the recipient's share code and signed by yours. Send it with the share sheet, and send your own share code to them separately so they can verify who created it.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Create a share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .data,
                defaultFilename: prepared?.fileName ?? "Grow-share"
            ) { result in
                handleExport(result)
            }
            .alert("Share problem", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Share a grow view")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("Only the rooms, plants and categories you choose are included. The cultivation journal, photos and your county are never part of a share.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recipientCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recipient", subtitle: "A label for your own records, and their share code")

            TextField("Consultant or peer", text: $recipientLabel)
                .textFieldStyle(.plain)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
                .accessibilityLabel("Recipient label")

            TextField("Their share code", text: $recipientCode, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(3...5)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
                .accessibilityLabel("Recipient share code")

            if !recipientCode.isEmpty && !ShareCode.isValid(recipientCode) {
                Text("That does not look like a share code. Ask the recipient to copy it from their own Sync and privacy screen.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Scope", subtitle: "Select at least one room or plant")

            if roomNames.isEmpty && plantNames.isEmpty {
                Text("Add a room or plant before creating a share.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.amber)
            }

            ForEach(roomNames, id: \.self) { name in
                ShareSelectionRow(
                    title: name,
                    icon: "square.split.2x2",
                    isSelected: selectedRooms.contains(name)
                ) {
                    toggle(name, in: &selectedRooms)
                }
            }

            ForEach(plantNames, id: \.self) { name in
                ShareSelectionRow(
                    title: name,
                    icon: "leaf",
                    isSelected: selectedPlants.contains(name)
                ) {
                    toggle(name, in: &selectedPlants)
                }
            }
        }
        .growCard()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Categories", subtitle: "Exactly what the recipient may see")

            ForEach(ShareCategory.allCases) { category in
                ShareSelectionRow(
                    title: category.title,
                    subtitle: category.subtitle,
                    icon: "checkmark.shield",
                    isSelected: selectedCategories.contains(category)
                ) {
                    toggle(category)
                }
            }

            ShareSelectionRow(
                title: "Cultivation journal and photos",
                subtitle: "Never shareable",
                icon: "lock",
                isSelected: false,
                isEnabled: false
            ) {}

            ShareSelectionRow(
                title: "County or city",
                subtitle: "Never shareable",
                icon: "lock",
                isSelected: false,
                isEnabled: false
            ) {}
        }
        .growCard()
    }

    private var expiryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Expiry")
            DatePicker(
                "Access ends",
                selection: $expiresAt,
                in: Date()...maxExpiry,
                displayedComponents: .date
            )
            .tint(Theme.primary)
            .font(Theme.sans(14))

            Text("The recipient's copy checks this date when it is opened. A file already handed over cannot be recalled, so treat the expiry as a limit on use, not a lock.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var maxExpiry: Date {
        Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
    }

    // MARK: Actions

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func toggle(_ category: ShareCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func prepare() {
        let scope = ShareScope(
            rooms: selectedRooms.sorted(),
            plants: selectedPlants.sorted(),
            categories: selectedCategories.sorted { $0.rawValue < $1.rawValue },
            expiresAt: expiresAt
        )

        do {
            let result = try service.prepareShare(
                source: source,
                scope: scope,
                recipientCode: recipientCode
            )
            prepared = result
            exportDocument = ExportDocument(data: result.data)
            showingExporter = true
        } catch {
            show(error)
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            recordShare()
            onShared()
            dismiss()
        case .failure(let error):
            show(error)
        }
    }

    private func recordShare() {
        guard let prepared else { return }
        let grant = ShareGrant(
            recipientName: recipientLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            roomNames: prepared.payload.scope.rooms,
            plantNames: prepared.payload.scope.plants,
            categories: prepared.payload.scope.categories.map(\.title),
            expiresAt: prepared.payload.expiresAt
        )
        context.insert(grant)
        context.insert(ShareAccessLog(action: "Created", grant: grant))
        try? context.save()
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
    }
}

struct ShareSelectionRow: View {
    let title: String
    var subtitle: String?
    let icon: String
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.sans(14, weight: .semibold))
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.sans(11))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(
                isEnabled
                    ? (isSelected ? Theme.primary : Theme.secondaryInk)
                    : Theme.tertiaryInk
            )
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
