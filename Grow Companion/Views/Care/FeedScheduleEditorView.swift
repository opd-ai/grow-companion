//
//  FeedScheduleEditorView.swift
//  Grow Companion
//
//  Create or edit a feed schedule: a name, a week count, and each week's
//  products, doses per litre and target pH and EC.
//

import SwiftUI
import SwiftData

struct FeedScheduleEditorView: View {
    var schedule: FeedSchedule? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var weekCount = 8
    @State private var weeks: [FeedWeekDraft] = []
    @State private var didLoad = false

    private var isEditing: Bool { schedule != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit feed schedule" : "New feed schedule")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Keep one mix per week. The room shows the week it is in, counting from the day you apply it.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    field("Name", placeholder: "Coco run", text: $name)

                    weekCountCard

                    ForEach(weeks.indices, id: \.self) { index in
                        FeedWeekDraftCard(week: $weeks[index])
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
                        .foregroundStyle(canSave ? Theme.primary : Theme.tertiaryInk)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: weekCount) { _, newValue in
            guard didLoad else { return }
            adjustWeeks(to: min(16, max(1, newValue)))
        }
    }

    // MARK: Fields

    private var weekCountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Weeks")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(weekCount) week\(weekCount == 1 ? "" : "s")")
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("How many weeks the mix runs for")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                }
                Spacer(minLength: 8)
                Stepper("Weeks", value: $weekCount, in: 1...16)
                    .labelsHidden()
                    .tint(Theme.primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surfaceSunken)
            )
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.sans(16))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
        }
    }

    // MARK: Load and save

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        guard let schedule else {
            weekCount = 8
            weeks = (1...8).map {
                FeedWeekDraft(number: $0, ph: "", ec: "", products: [])
            }
            return
        }

        name = schedule.name
        weekCount = min(16, max(1, schedule.weekCount))
        weeks = (1...weekCount).map { number in
            let existing = schedule.week(number)
            return FeedWeekDraft(
                number: number,
                ph: existing?.targetPH.map { String(format: "%.1f", $0) } ?? "",
                ec: existing?.targetEC.map { String(format: "%.2f", $0) } ?? "",
                products: (existing?.sortedProducts ?? []).map { product in
                    FeedProductDraft(
                        name: product.name,
                        dose: product.doseMLPerLiter.map { String(format: "%g", $0) } ?? ""
                    )
                }
            )
        }
    }

    private func adjustWeeks(to target: Int) {
        if target > weeks.count {
            for number in (weeks.count + 1)...target {
                weeks.append(FeedWeekDraft(number: number, ph: "", ec: "", products: []))
            }
        } else if target < weeks.count {
            weeks.removeLast(weeks.count - target)
        }
    }

    private func number(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized) else { return nil }
        return value
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let count = min(16, max(1, weekCount))
        let drafts = Array(weeks.prefix(count))

        if let schedule {
            schedule.name = trimmedName
            schedule.weekCount = count

            for week in Array(schedule.weeks) where week.weekNumber > count {
                context.delete(week)
            }

            for draft in drafts {
                let week = schedule.week(draft.number) ?? makeWeek(number: draft.number, in: schedule)
                week.targetPH = number(draft.ph)
                week.targetEC = number(draft.ec)
                syncProducts(draft.products, in: week)
            }
        } else {
            let created = FeedSchedule(name: trimmedName, weekCount: count)
            context.insert(created)

            for draft in drafts {
                let week = makeWeek(number: draft.number, in: created)
                week.targetPH = number(draft.ph)
                week.targetEC = number(draft.ec)
                syncProducts(draft.products, in: week)
            }
        }

        try? context.save()
        dismiss()
    }

    private func makeWeek(number: Int, in schedule: FeedSchedule) -> FeedWeek {
        let week = FeedWeek(weekNumber: number)
        context.insert(week)
        week.schedule = schedule
        return week
    }

    private func syncProducts(_ drafts: [FeedProductDraft], in week: FeedWeek) {
        let existing = week.sortedProducts
        let cleaned = drafts
            .map { draft in
                (
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    dose: draft.dose
                )
            }
            .filter { !$0.name.isEmpty }

        for (index, item) in cleaned.enumerated() {
            if index < existing.count {
                let product = existing[index]
                product.name = item.name
                product.doseMLPerLiter = number(item.dose)
                product.sortIndex = index
            } else {
                let product = FeedProduct(
                    name: item.name,
                    doseMLPerLiter: number(item.dose),
                    sortIndex: index
                )
                context.insert(product)
                product.week = week
            }
        }

        if existing.count > cleaned.count {
            for product in existing.dropFirst(cleaned.count) {
                context.delete(product)
            }
        }
    }
}

// MARK: - Drafts and week card

struct FeedProductDraft: Identifiable {
    let id = UUID()
    var name: String
    var dose: String
}

struct FeedWeekDraft: Identifiable {
    let id = UUID()
    let number: Int
    var ph: String
    var ec: String
    var products: [FeedProductDraft]
}

private struct FeedWeekDraftCard: View {
    @Binding var week: FeedWeekDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Week \(week.number)")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                targetField("Target pH", placeholder: "5.9", text: $week.ph)
                targetField("Target EC", placeholder: "1.8", text: $week.ec)
            }

            ForEach(week.products.indices, id: \.self) { index in
                productRow(index: index)
            }

            Button {
                week.products.append(FeedProductDraft(name: "", dose: ""))
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Add a product")
                        .font(Theme.sans(12, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
        }
        .growCard(padding: 14)
    }

    private func productRow(index: Int) -> some View {
        HStack(spacing: 8) {
            TextField("Product", text: $week.products[index].name)
                .textFieldStyle(.plain)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.ink)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )

            TextField("ml/L", text: $week.products[index].dose)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )

            Button {
                week.products.remove(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove product")
        }
    }

    private func targetField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(1)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surfaceSunken)
        )
    }
}
