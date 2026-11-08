//
//  ScoutingCheckEditor.swift
//  Grow Companion
//
//  Log or edit a plant or room scouting check.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ScoutingCheckEditor: View {
    let plant: Plant?
    let room: Room?
    var check: ScoutingCheck? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var selectedFindings = Set<ObservationTag>()
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingDelete = false

    private var isEditing: Bool { check != nil }
    private var targetName: String { plant?.displayName ?? room?.name ?? "this grow" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit scouting check" : "Log scouting check")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Record what you see on \(targetName). Add more than one finding when it helps describe the check.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        label("Findings")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(ObservationTag.allCases) { finding in
                                Button {
                                    if selectedFindings.contains(finding) { selectedFindings.remove(finding) } else { selectedFindings.insert(finding) }
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: finding.systemImage).font(.system(size: 12, weight: .semibold))
                                        Text(finding.title).font(Theme.sans(12, weight: .semibold)).lineLimit(1)
                                    }
                                    .foregroundStyle(selectedFindings.contains(finding) ? Theme.primary : Theme.secondaryInk)
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selectedFindings.contains(finding) ? Theme.sageSoft : Theme.surfaceSunken))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        Text("Date")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))

                    VStack(alignment: .leading, spacing: 8) {
                        label("Note (optional)")
                        TextField("What did you notice?", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        label("Photo (optional)")
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(photoData == nil ? "Add a photo" : "Photo selected", systemImage: photoData == nil ? "camera" : "checkmark.circle")
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.primary.opacity(0.25), lineWidth: 1))
                        }
                        if check?.photoFileName != nil && photoData == nil {
                            Text("A photo is already attached. Pick another to replace it.")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                        }
                    }

                    if isEditing {
                        Button { showingDelete = true } label: {
                            Text("Delete this check")
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).foregroundStyle(Theme.primary)
                }
            }
        }
        .onAppear(perform: load)
        .task(id: photoItem) {
            guard let photoItem else { return }
            photoData = try? await photoItem.loadTransferable(type: Data.self)
        }
        .confirmationDialog("Delete this scouting check?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete check", role: .destructive) {
                if let check {
                    if let fileName = check.photoFileName { PhotoStore.delete(named: fileName) }
                    context.delete(check)
                    try? context.save()
                }
                dismiss()
            }
            Button("Keep check", role: .cancel) {}
        } message: {
            Text("The check is removed from the scouting history.")
        }
    }

    private func label(_ title: String) -> some View {
        Text(title).font(Theme.sans(11, weight: .semibold)).textCase(.uppercase).foregroundStyle(Theme.secondaryInk)
    }

    private func load() {
        guard let check else { return }
        date = check.date
        selectedFindings = Set(check.findings)
        note = check.note
    }

    private func save() {
        let photoFileName: String?
        if let photoData, let saved = PhotoStore.save(imageData: photoData) {
            if let old = check?.photoFileName, old != saved { PhotoStore.delete(named: old) }
            photoFileName = saved
        } else {
            photoFileName = check?.photoFileName
        }

        if let check {
            check.date = date
            check.findings = Array(selectedFindings)
            check.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            check.photoFileName = photoFileName
        } else {
            let created = ScoutingCheck(date: date, findings: Array(selectedFindings), note: note.trimmingCharacters(in: .whitespacesAndNewlines), photoFileName: photoFileName, plant: plant, room: room)
            context.insert(created)
        }
        try? context.save()
        dismiss()
    }
}
