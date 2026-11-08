//
//  TrainingSessionEditor.swift
//  Grow Companion
//
//  Log or edit one training session: method, date, nodes affected and a note.
//  The date can be moved into the past to backdate a session.
//

import SwiftUI
import SwiftData

struct TrainingSessionEditor: View {
    let plant: Plant
    var session: TrainingSession? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var method: TrainingMethod = .topping
    @State private var date = Date()
    @State private var nodesText = ""
    @State private var note = ""
    @State private var showingDelete = false

    private var isEditing: Bool { session != nil }

    private var nodes: Int? {
        let trimmed = nodesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit training" : "Log training")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Record what you did to \(plant.displayName) and when. A session can be backdated.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    methodPicker

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
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        label("Nodes affected (optional)")
                        TextField("e.g. 4", text: $nodesText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .font(Theme.sans(16))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Note (optional)")
                        TextField("What you did and how it looked", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }

                    if isEditing {
                        Button {
                            showingDelete = true
                        } label: {
                            Text("Delete this session")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Delete this training session?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete session", role: .destructive) {
                if let session {
                    context.delete(session)
                    try? context.save()
                }
                dismiss()
            }
            Button("Keep session", role: .cancel) {}
        } message: {
            Text("The session is removed from the plant's training history.")
        }
    }

    // MARK: Fields

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Method")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(TrainingMethod.allCases) { option in
                    Button {
                        method = option
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                            Text(option.title)
                                .font(Theme.sans(12, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(method == option ? Theme.primary : Theme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(method == option ? Theme.sageSoft : Theme.surfaceSunken)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(method.subtitle)
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }

    // MARK: Data

    private func load() {
        guard let session else { return }
        method = session.method
        date = session.date
        nodesText = session.nodesAffected.map(String.init) ?? ""
        note = session.note
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let session {
            session.method = method
            session.date = date
            session.nodesAffected = nodes
            session.note = trimmedNote
        } else {
            let created = TrainingSession(
                method: method,
                date: date,
                nodesAffected: nodes,
                note: trimmedNote
            )
            context.insert(created)
            created.plant = plant
        }

        try? context.save()
        dismiss()
    }
}
