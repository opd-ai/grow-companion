import SwiftUI
import WidgetKit

// MARK: - Shared payload

/// The same shape the app writes into the App Group container.
struct CareWidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var dueToday: Int
    var overdue: Int
    /// Empty unless the grower allowed task names in the app's settings.
    var titles: [String]
    /// Localized headline and overdue line, written by the app so the widget
    /// shows the app's language. Optional: an older snapshot has neither.
    var headline: String?
    var overdueText: String?
}

enum CareWidgetStore {
    static let appGroupIdentifier = "group.com.organizationName.Grow-Companion.shared"
    static let fileName = "care-snapshot.json"

    static func read() -> CareWidgetSnapshot? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let url = container.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CareWidgetSnapshot.self, from: data)
    }
}

// MARK: - Timeline

struct CareWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: CareWidgetSnapshot?
}

struct CareWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CareWidgetEntry {
        CareWidgetEntry(
            date: Date(),
            snapshot: CareWidgetSnapshot(
                generatedAt: Date(),
                dueToday: 2,
                overdue: 0,
                titles: []
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CareWidgetEntry) -> Void) {
        completion(CareWidgetEntry(date: Date(), snapshot: CareWidgetStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CareWidgetEntry>) -> Void) {
        let entry = CareWidgetEntry(date: Date(), snapshot: CareWidgetStore.read())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct CareWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CareWidgetEntry

    private var snapshot: CareWidgetSnapshot? { entry.snapshot }
    private var due: Int { snapshot?.dueToday ?? 0 }
    private var overdue: Int { snapshot?.overdue ?? 0 }
    private var titles: [String] { snapshot?.titles ?? [] }
    private var total: Int { due + overdue }

    private var headline: String {
        if let headline = snapshot?.headline { return headline }
        guard total > 0 else { return "No care tasks today" }
        return "\(total) care task\(total == 1 ? "" : "s") today"
    }

    private var overdueLabel: String {
        snapshot?.overdueText ?? "\(overdue) overdue"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                accessory
            default:
                card
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grow Companion")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            if overdue > 0 {
                Text(overdueLabel)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(titles, id: \.self) { title in
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(uiColor: .secondarySystemBackground)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(headline)
                .font(.headline)
                .widgetAccentable()

            if let first = titles.first {
                Text(first)
                    .font(.caption2)
                    .lineLimit(1)
            } else if overdue > 0 {
                Text(overdueLabel)
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityText: String {
        var parts = [headline]
        if overdue > 0 {
            parts.append(overdueLabel)
        }
        if !titles.isEmpty {
            parts.append(titles.joined(separator: ", "))
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Widget

struct CareWidget: Widget {
    static let kind = "CareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CareWidgetProvider()) { entry in
            CareWidgetView(entry: entry)
                .widgetURL(URL(string: "growcompanion://today"))
        }
        .configurationDisplayName("Today's care")
        .description("How many care tasks are due. Task names appear only if you allow them in Settings.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

@main
struct GrowCompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CareWidget()
    }
}
