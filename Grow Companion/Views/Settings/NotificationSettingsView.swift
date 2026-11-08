//
//  NotificationSettingsView.swift
//  Grow Companion
//
//  Priority per notification category, quiet hours and the generic copy that
//  keeps plant and room names off a locked screen.
//

import SwiftUI
import SwiftData
import UserNotifications

struct NotificationSettingsView: View {
    @Query(sort: \CareReminder.nextDueDate) private var reminders: [CareReminder]
    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var priorities: [NotificationCategory: NotificationPriority] = [:]
    @State private var quietEnabled = false
    @State private var quietStartMinute = 22 * 60
    @State private var quietEndMinute = 7 * 60
    @State private var genericContent = true
    @State private var digestEnabled = false
    @State private var digestTimeMinute = 8 * 60
    @State private var digestRoomIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text("When reminders arrive, how loud they are, and what a locked screen is allowed to show.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                statusCard
                priorityCard
                quietHoursCard
                digestCard
                lockScreenCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            notificationStatus = await CareNotifications.authorizationStatus()
            loadPreferences()
        }
        .onChange(of: quietEnabled) { _, _ in saveQuietHours() }
        .onChange(of: quietStartMinute) { _, _ in saveQuietHours() }
        .onChange(of: quietEndMinute) { _, _ in saveQuietHours() }
        .onChange(of: genericContent) { _, value in
            NotificationSettings.setGenericContent(value)
            CareNotifications.refresh(reminders)
            CareDigest.schedule(rooms: rooms)
        }
        .onChange(of: digestEnabled) { _, _ in saveDigest() }
        .onChange(of: digestTimeMinute) { _, _ in saveDigest() }
        .onChange(of: digestRoomIDs) { _, _ in saveDigest() }
    }

    // MARK: Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Alerts", subtitle: "Local reminders, delivered on this device")
            HStack {
                Text("Status")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Text(statusLabel)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(isNotificationsOn ? Theme.primary : Theme.amber)
            }
            if notificationStatus == .notDetermined || notificationStatus == .denied {
                SecondaryButton("Enable notifications", systemImage: "bell") {
                    Task {
                        _ = await CareNotifications.requestAuthorization()
                        notificationStatus = await CareNotifications.authorizationStatus()
                    }
                }
            }
            if notificationStatus == .denied {
                Text("If notifications stay off, allow them for Grow Companion in iOS Settings.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    private var isNotificationsOn: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional || notificationStatus == .ephemeral
    }

    private var statusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return String(localized: "On")
        case .denied: return String(localized: "Off")
        case .notDetermined: return String(localized: "Not set up")
        @unknown default: return String(localized: "Unknown")
        }
    }

    // MARK: Priorities

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Priority", subtitle: "Set per category")

            VStack(spacing: 12) {
                ForEach(NotificationCategory.allCases) { category in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.sageSoft)
                                .frame(width: 30, height: 30)
                            Image(systemName: category.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.title)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(currentPriority(category).subtitle)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        priorityMenu(for: category)
                    }
                }
            }

            Text("Critical uses the strongest interruption a local notification can ask for without Apple's critical-alert entitlement. Routine arrives quietly.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private func currentPriority(_ category: NotificationCategory) -> NotificationPriority {
        priorities[category] ?? category.defaultPriority
    }

    private func priorityMenu(for category: NotificationCategory) -> some View {
        Menu {
            ForEach(NotificationPriority.allCases) { priority in
                Button {
                    priorities[category] = priority
                    NotificationSettings.setPriority(priority, for: category)
                    CareNotifications.refresh(reminders)
                } label: {
                    if currentPriority(category) == priority {
                        Label(priority.title, systemImage: "checkmark")
                    } else {
                        Text(priority.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentPriority(category).title)
                    .font(Theme.sans(12, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.sageSoft))
        }
    }

    // MARK: Quiet hours

    private var quietHoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Quiet hours", subtitle: "Hold the routine reminders")

            Toggle(isOn: $quietEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quiet hours")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Reminders that land inside the window move to its end.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.primary)

            if quietEnabled {
                HStack {
                    Text("From")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer()
                    DatePicker(
                        "Start",
                        selection: timeBinding(minutes: $quietStartMinute),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(Theme.primary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )

                HStack {
                    Text("To")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer()
                    DatePicker(
                        "End",
                        selection: timeBinding(minutes: $quietEndMinute),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(Theme.primary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )

                Text("Critical reminders still arrive on time inside quiet hours.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    private func timeBinding(minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let base = calendar.startOfDay(for: Date())
                return calendar.date(
                    bySettingHour: minutes.wrappedValue / 60,
                    minute: minutes.wrappedValue % 60,
                    second: 0,
                    of: base
                ) ?? base
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func saveQuietHours() {
        NotificationSettings.saveQuietHours(
            enabled: quietEnabled,
            startMinutes: quietStartMinute,
            endMinutes: quietEndMinute
        )
        CareNotifications.refresh(reminders)
        CareDigest.schedule(rooms: rooms)
    }

    // MARK: Daily digest

    private var digestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Daily care digest", subtitle: "A private, local summary of your selected rooms")

            Toggle(isOn: $digestEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send a daily digest")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Includes recorded care activity and scheduled tasks that are still unfinished. Journal entries and location are never included.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.primary)

            if digestEnabled {
                HStack {
                    Text("Delivery time")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer()
                    DatePicker(
                        "Delivery time",
                        selection: timeBinding(minutes: $digestTimeMinute),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(Theme.primary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rooms in this digest")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if rooms.isEmpty {
                        Text("Add a room before enabling a digest.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.tertiaryInk)
                    } else {
                        ForEach(rooms) { room in
                            Toggle(isOn: roomSelectionBinding(for: room)) {
                                Label(room.name, systemImage: "square.split.2x2")
                                    .font(Theme.sans(13))
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            .tint(Theme.primary)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))

                Text("The digest follows your quiet hours and uses the same protected-screen wording as other notifications.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink {
                CareDigestPreviewView()
            } label: {
                SettingsLinkRow(
                    icon: "calendar.day.timeline.left",
                    title: "Preview care digest",
                    value: "Review selected-room activity and unfinished tasks"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private func roomSelectionBinding(for room: Room) -> Binding<Bool> {
        let id = CareDigest.roomID(room)
        return Binding(
            get: { digestRoomIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    digestRoomIDs.insert(id)
                } else {
                    digestRoomIDs.remove(id)
                }
            }
        )
    }

    private func saveDigest() {
        CareDigestPreferences(
            enabled: digestEnabled,
            timeOfDayMinutes: digestTimeMinute,
            roomIDs: digestRoomIDs
        ).save()
        CareDigest.schedule(rooms: rooms)
    }

    // MARK: Lock-screen content

    private var lockScreenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Lock-screen content", subtitle: "What a protected screen may show")

            Toggle(isOn: $genericContent) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generic notification text")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Every notification reads \"A care task is due\", so nothing about the grow is visible on a locked screen.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.primary)

            Text("Even with this off, Grow Companion never puts a plant, room or strain name in a notification. Turning it off only shows the care category, such as Watering.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    // MARK: Data

    private func loadPreferences() {
        for category in NotificationCategory.allCases {
            priorities[category] = NotificationSettings.priority(for: category)
        }
        quietEnabled = NotificationSettings.quietHoursEnabled
        quietStartMinute = NotificationSettings.quietHoursStart
        quietEndMinute = NotificationSettings.quietHoursEnd
        genericContent = NotificationSettings.usesGenericContent
        let digest = CareDigestPreferences.current
        digestEnabled = digest.enabled
        digestTimeMinute = digest.timeOfDayMinutes
        digestRoomIDs = digest.roomIDs
        CareDigest.schedule(rooms: rooms)
    }
}
