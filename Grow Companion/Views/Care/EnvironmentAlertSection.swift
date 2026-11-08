import SwiftUI

struct EnvironmentAlertSection: View {
    let room: Room
    @Environment(\.modelContext) private var context

    private var alerts: [EnvironmentAlert] { room.environmentAlerts.sorted { $0.detectedAt > $1.detectedAt } }

    var body: some View {
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Environment alerts", subtitle: "Sustained excursions")
                VStack(spacing: 0) {
                    ForEach(alerts) { alert in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: alert.isAcknowledged ? "checkmark.circle" : "exclamationmark.triangle.fill")
                                .foregroundStyle(alert.isAcknowledged ? Theme.primary : Theme.amber)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(alert.metric.title) · \(alert.metric.display(alert.value, unit: .metric))")
                                    .font(Theme.sans(13, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text("Target \(alert.metric.displayTarget(alert.target, unit: .metric)) · \(Format.shortDate(alert.detectedAt))")
                                    .font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 4)
                            if !alert.isAcknowledged {
                                Button("Acknowledge") {
                                    alert.acknowledgedAt = Date()
                                    CareNotifications.cancel(identifier: alert.notificationIdentifier)
                                    try? context.save()
                                }
                                .font(Theme.sans(11, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                            }
                        }
                        .padding(.vertical, 9)
                        if alert.id != alerts.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
                .growCard(fill: Theme.amberSoft, padding: 14)
            }
        }
    }
}
