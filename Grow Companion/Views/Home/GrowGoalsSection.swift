//
//  GrowGoalsSection.swift
//  Grow Companion
//
//  The grower's own cycle targets on the weekly recap, with the value the
//  record supports and the target beside it. Optional, local, and never a
//  grade: a target with nothing to measure says so instead of showing zero.
//

import SwiftUI
import SwiftData

struct GrowGoalsSection: View {
    let goal: GrowGoal?
    let sources: GrowGoalSources
    let unit: UnitSystem

    @State private var showingEditor = false

    private var progress: [GoalProgress] {
        GrowGoalService.progress(goal: goal, sources: sources, unit: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Cycle goals")
                    .font(Theme.serif(29))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 8)

                Button {
                    showingEditor = true
                } label: {
                    Text(goal?.hasAnyTarget == true ? "Edit" : "Set")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.sageSoft))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    goal?.hasAnyTarget == true ? "Edit this cycle's goals" : "Set this cycle's goals"
                )
            }

            if progress.isEmpty {
                emptyCard
            } else {
                VStack(spacing: 14) {
                    ForEach(progress) { item in
                        row(for: item)
                    }
                }
                .growCard(padding: 16)
            }

            Text("Targets are yours alone. The app never grades the grow, ranks it or compares it with anyone else's.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $showingEditor) {
            GrowGoalsEditor(goal: goal)
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No targets set")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Optional. A dry-yield, flowering-time or logging target turns this into a read-out against your own number.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surface, padding: 16)
    }

    private func row(for item: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.sageSoft))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.kind.title)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(item.statusText)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceSunken)
                    if let fraction = item.fraction {
                        Capsule()
                            .fill(Theme.primary)
                            .frame(width: max(4, proxy.size.width * fraction))
                    }
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.title). \(item.statusText).")
    }
}

/// The editor for the three optional targets. Saving with every target off
/// removes the stored record, so nothing empty is left in export or backup.
struct GrowGoalsEditor: View {
    let goal: GrowGoal?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var yieldEnabled = false
    @State private var weeksEnabled = false
    @State private var completenessEnabled = false

    @State private var yieldText = ""
    @State private var weeksText = ""
    @State private var completenessText = ""

    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cycle goals")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("Optional targets for this cycle. They stay on this device, appear in your export and backup, and are removed with everything else when you delete all data.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    targetCard(
                        kind: .dryYield,
                        enabled: $yieldEnabled,
                        text: $yieldText,
                        placeholder: "e.g. 250",
                        keyboard: .decimalPad
                    )

                    targetCard(
                        kind: .floweringWeeks,
                        enabled: $weeksEnabled,
                        text: $weeksText,
                        placeholder: "e.g. 9",
                        keyboard: .numberPad
                    )

                    targetCard(
                        kind: .loggingCompleteness,
                        enabled: $completenessEnabled,
                        text: $completenessText,
                        placeholder: "e.g. 80",
                        keyboard: .numberPad
                    )

                    if !errorMessage.isEmpty {
                        CareInput.warning(errorMessage)
                    }

                    PrimaryButton("Save goals", systemImage: "checkmark") {
                        save()
                    }

                    if goal != nil {
                        Button {
                            remove()
                        } label: {
                            Text("Remove all goals")
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.dangerSoft)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Removes every target for this cycle")
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
            }
        }
        .onAppear(perform: load)
    }

    private func targetCard(
        kind: GrowGoalKind,
        enabled: Binding<Bool>,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(kind.subtitle)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.primary)

            if enabled.wrappedValue {
                CareInput.field(placeholder: placeholder, text: text, keyboard: keyboard)
                    .accessibilityLabel("\(kind.title) target")
            }
        }
        .growCard(padding: 16)
    }

    private func load() {
        guard let goal else { return }

        if let grams = goal.dryYieldTargetGrams {
            yieldEnabled = true
            yieldText = String(format: "%.0f", grams)
        }
        if let weeks = goal.floweringWeeksTarget {
            weeksEnabled = true
            weeksText = String(weeks)
        }
        if let percent = goal.loggingCompletenessTargetPercent {
            completenessEnabled = true
            completenessText = String(percent)
        }
    }

    private func save() {
        errorMessage = ""

        guard let yieldChoice = choice(enabled: yieldEnabled, text: yieldText, label: "dry-yield"),
              let weeksChoice = choice(enabled: weeksEnabled, text: weeksText, label: "flowering-time"),
              let completenessChoice = choice(
                enabled: completenessEnabled,
                text: completenessText,
                label: "logging"
              )
        else { return }

        do {
            try GrowGoalService.save(
                dryYieldTargetGrams: yieldChoice.value,
                floweringWeeksTarget: weeksChoice.value.map { Int($0.rounded()) },
                loggingCompletenessTargetPercent: completenessChoice.value.map { Int($0.rounded()) },
                existing: goal,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A target the grower turned on, or `off` when the switch is off. An
    /// enabled field with no number is an error instead of a silent nil.
    private func choice(enabled: Bool, text: String, label: String) -> TargetChoice? {
        guard enabled else { return .off }
        guard let value = CareInput.number(text) else {
            errorMessage = "Enter a \(label) target, or turn it off."
            return nil
        }
        return .value(value)
    }

    private func remove() {
        errorMessage = ""
        do {
            try GrowGoalService.save(
                dryYieldTargetGrams: nil,
                floweringWeeksTarget: nil,
                loggingCompletenessTargetPercent: nil,
                existing: goal,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


private extension GrowGoalsEditor {
    /// A target the grower turned on, or `off` when the switch is off.
    enum TargetChoice {
        case off
        case value(Double)

        var value: Double? {
            switch self {
            case .off: return nil
            case .value(let number): return number
            }
        }
    }
}
