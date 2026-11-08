//
//  SettingsView.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    let profile: GrowProfile

    @Environment(AppLock.self) private var appLock

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var showingChange = false

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text("Units, alerts and the legal detail behind the numbers.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                }

                profileCard
                unitsCard
                alertsCard
                privacyCard
                educationCard
                performanceCard
                anomalyCard
                harvestPlanningCard
                syncPrivacyCard
                FederalNoticeCard()
                VerificationDutyCard()
                aboutCard
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingChange) {
            ChangeJurisdictionSheet(profile: profile)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your grow profile")

            InfoRow(label: "State", value: profile.stateName.isEmpty ? "Not set" : profile.stateName)
            InfoRow(label: "County or city", value: profile.countyOrCity.isEmpty ? "Not set" : profile.countyOrCity)
            InfoRow(label: "Residence", value: profile.residenceType.title)
            if profile.residenceType == .rental {
                InfoRow(label: "Landlord consent", value: profile.landlordConsent ? "Yes" : "Not recorded")
            }
            InfoRow(label: "Experience", value: profile.experienceLevel.title)
            InfoRow(
                label: "Age confirmed",
                value: profile.ageAttestedAt.map { Format.shortDate($0) } ?? "Not recorded"
            )
            InfoRow(label: "Rule pack", value: "\(RulePack.version) · rules last updated \(RulePack.displayDate(RulePack.verifiedOn))")

            SecondaryButton("Change jurisdiction", systemImage: "mappin.and.ellipse") {
                showingChange = true
            }
        }
        .growCard()
    }

    private var unitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Units", subtitle: "Applies to every weight and area in the app")
            Picker("Units", selection: $unitRaw) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.title).tag(system.rawValue)
                }
            }
            .pickerStyle(.segmented)
            Text(unit.subtitle)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .growCard()
    }

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Compliance warning", subtitle: "When the card turns amber")
            HStack {
                Text("Warn at")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Text(Format.percent(warningThreshold))
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
            Slider(value: $warningThreshold, in: 0.5...1.0, step: 0.05)
                .tint(Theme.primary)
            Text("Grow Companion always tracks the exact limit. This only decides how early the warning appears.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Privacy and data", subtitle: "Lock, alerts and what leaves this device")

            NavigationLink {
                AppLockView()
            } label: {
                SettingsLinkRow(
                    icon: "faceid",
                    title: "App lock",
                    value: appLock.statusText
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)

            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsLinkRow(
                    icon: "bell.badge",
                    title: "Notifications",
                    value: "Priorities, quiet hours and lock-screen text"
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)

            NavigationLink {
                SensorConnectionsView()
            } label: {
                SettingsLinkRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Room sensors",
                    value: "Trusted BLE and Wi-Fi environment readings"
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)

            NavigationLink {
                SharingView()
            } label: {
                SettingsLinkRow(
                    icon: "person.badge.shield.checkmark",
                    title: "Sharing",
                    value: "Scoped, encrypted share files"
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)

            NavigationLink {
                BackupView()
            } label: {
                SettingsLinkRow(
                    icon: "externaldrive.badge.plus",
                    title: "Backup and restore",
                    value: "Protected copy on this device or Files"
                )
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)

            NavigationLink {
                DataControlsView()
            } label: {
                SettingsLinkRow(
                    icon: "externaldrive",
                    title: "Export and delete",
                    value: "Your data, in your hands"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private var educationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Learn", subtitle: "Offline lessons and practical checklists")
            NavigationLink {
                EducationLibraryView()
            } label: {
                SettingsLinkRow(
                    icon: "book.closed",
                    title: "Education library",
                    value: "Fundamentals, pest checks, curing and compliance"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Reports", subtitle: "Read-only views of your existing records")
            NavigationLink {
                PerformanceReportView()
            } label: {
                SettingsLinkRow(
                    icon: "chart.xyaxis.line",
                    title: "Performance trends",
                    value: "Yield, flowering duration and environment signals"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private var anomalyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Review", subtitle: "Read-only environment pattern checks")
            NavigationLink {
                AnomalyReviewView()
            } label: {
                SettingsLinkRow(
                    icon: "exclamationmark.triangle",
                    title: "Environment anomalies",
                    value: "Review unusual temperature and humidity shifts"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private var harvestPlanningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Planning", subtitle: "Read-only flowering forecasts")
            NavigationLink {
                HarvestPlanningView()
            } label: {
                SettingsLinkRow(
                    icon: "calendar.badge.clock",
                    title: "Harvest planning",
                    value: "Forecast windows and flowering sources"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private var syncPrivacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Privacy", subtitle: "What stays on this device")
            NavigationLink {
                SyncPrivacyView()
            } label: {
                SettingsLinkRow(
                    icon: "lock.icloud",
                    title: "Sync and privacy",
                    value: "No account and no cloud sync"
                )
            }
            .buttonStyle(.plain)
        }
        .growCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("About")
            Text("Grow Companion \(appVersion)")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(LegalCopy.privacy)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12, weight: .semibold))
                Text("On-device store protected with complete file protection.")
                    .font(Theme.sans(12))
            }
            .foregroundStyle(Theme.primary)
        }
        .growCard()
    }
}


// MARK: - Row

struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(value)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
