//
//  BreederNoteEditor.swift
//  Grow Companion
//
//  The grower's own notes for one breeder. The bundled reference is never
//  edited here: a bundled breeder keeps its name and the notes sit beside it,
//  so the claim and the grower's own experience stay separate.
//

import SwiftUI
import SwiftData

struct BreederNoteEditor: View {
    let name: String
    let existing: GrowerBreeder?
    let isBundledBreeder: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String
    @State private var notes: String
    @State private var website: String
    @State private var errorMessage: String?
    @State private var showingDelete = false

    init(name: String, existing: GrowerBreeder?, isBundledBreeder: Bool) {
        self.name = name
        self.existing = existing
        self.isBundledBreeder = isBundledBreeder
        _draftName = State(initialValue: existing?.name ?? name)
        _notes = State(initialValue: existing?.notes ?? "")
        _website = State(initialValue: existing?.website ?? "")
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && websiteProblem == nil
    }

    private var websiteProblem: String? {
        let trimmed = website.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return GrowerBreederService.websiteURL(from: trimmed) == nil
            ? GrowerBreederError.invalidWebsite.errorDescription
            : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isBundledBreeder {
                    Section {
                        TextField("Breeder name", text: $draftName)
                    } header: {
                        Text("Breeder")
                    } footer: {
                        Text("Matched with your strains by name, ignoring case, accents and punctuation.")
                    }
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 150)
                        .accessibilityLabel(String(localized: "Your notes about this breeder"))
                } header: {
                    Text("Your notes")
                } footer: {
                    Text("Kept on this device. The bundled reference stays exactly as it is.")
                }

                Section {
                    TextField("https://example.com", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Website (optional)")
                } footer: {
                    if let websiteProblem {
                        Text(websiteProblem)
                            .foregroundStyle(Theme.amber)
                    } else {
                        Text("An https address, for your own reference.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDelete = true
                        } label: {
                            Label("Remove your notes", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(existing == nil
                ? String(localized: "Add a breeder")
                : String(localized: "Your notes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primary)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Remove your notes for this breeder?",
                isPresented: $showingDelete,
                titleVisibility: .visible
            ) {
                Button("Remove notes", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The bundled reference, if there is one, stays available.")
            }
        }
    }

    private func save() {
        do {
            try GrowerBreederService.save(
                name: draftName,
                notes: notes,
                website: website,
                existing: existing,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        guard let existing else { return }
        do {
            try GrowerBreederService.delete(existing, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
