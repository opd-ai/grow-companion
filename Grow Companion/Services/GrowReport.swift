//
//  GrowReport.swift
//  Grow Companion
//
//  A local, printable summary of the grow: the compliance estimate with its
//  rule-pack provenance, stage history, care summaries, training, treatments,
//  scouting and harvest. The report is built in the app and shared through the
//  system share sheet; nothing is uploaded.
//

import Foundation
import UIKit

struct GrowReportSection: Identifiable {
    let id: String
    let title: String
    let lines: [String]
}

struct GrowReportData {
    let generatedAt: Date
    let jurisdictionLabel: String
    let rulePackVersion: String
    let rulePackVerifiedOn: String
    let verificationDuty: String
    let sections: [GrowReportSection]
    let includesJournal: Bool
}

enum GrowReportService {
    static func makeData(
        plants: [Plant],
        rooms: [Room],
        profile: GrowProfile?,
        journal: [JournalEntry],
        rule: JurisdictionRule?,
        warningThreshold: Double,
        unit: UnitSystem,
        includeJournal: Bool,
        now: Date = Date()
    ) -> GrowReportData {
        let sections = [
            complianceSection(plants: plants, rooms: rooms, profile: profile, rule: rule, warningThreshold: warningThreshold, unit: unit),
            stageSection(plants: plants),
            careSection(plants: plants, rooms: rooms, unit: unit),
            trainingSection(plants: plants),
            treatmentSection(plants: plants, rooms: rooms),
            scoutingSection(plants: plants, rooms: rooms),
            harvestSection(plants: plants, unit: unit),
            scopeSection(includeJournal: includeJournal, journal: journal)
        ]

        return GrowReportData(
            generatedAt: now,
            jurisdictionLabel: jurisdictionLabel(profile: profile, rule: rule),
            rulePackVersion: RulePack.version,
            rulePackVerifiedOn: RulePack.verifiedOn,
            verificationDuty: LegalCopy.verificationDuty,
            sections: sections,
            includesJournal: includeJournal
        )
    }

    // MARK: Compliance

    private static func complianceSection(
        plants: [Plant],
        rooms: [Room],
        profile: GrowProfile?,
        rule: JurisdictionRule?,
        warningThreshold: Double,
        unit: UnitSystem
    ) -> GrowReportSection {
        var lines: [String] = [
            "Rule pack: \(RulePack.version) · rules last updated \(RulePack.displayDate(RulePack.verifiedOn))",
            "Warning threshold: \(Format.percent(warningThreshold))"
        ]

        if let rule {
            let report = ComplianceEngine.report(
                plants: plants,
                rooms: rooms,
                rule: rule,
                warningThreshold: warningThreshold
            )
            lines.append("Jurisdiction: \(rule.stateName) (\(rule.jurisdictionCode))")
            lines.append(
                "Counted plants: \(report.countedPlants) of \(report.plantLimit.map(String.init) ?? "no recorded limit") · \(report.plantLevel.title)"
            )
            lines.append(
                "Stored flower: \(Format.weight(report.possessionGrams, unit: unit)) of \(Format.weightLimit(report.possessionLimitGrams, unit: unit)) · \(report.possessionLevel.title)"
            )
            lines.append(
                "Canopy: \(Format.area(report.canopySqM, unit: unit)) of \(Format.areaLimit(report.canopyLimitSqM, unit: unit)) · \(report.canopyLevel.title)"
            )
            lines.append("Overall: \(report.overallLevel.title). \(report.statusDetail)")
            if !rule.countingNote.isEmpty {
                lines.append("Counting method: \(rule.countingNote)")
            }
            if !rule.citation.isEmpty {
                lines.append("Citation: \(rule.citation)")
            }
        } else {
            lines.append("Jurisdiction: \(profile?.stateName ?? "not set")")
            lines.append("No jurisdiction rule is selected, so no compliance count was calculated for this report.")
        }

        lines.append("This is the app's own calculation from local records, not legal advice.")
        return GrowReportSection(id: "compliance", title: "Compliance estimate", lines: lines)
    }

    // MARK: Stages

    private static func stageSection(plants: [Plant]) -> GrowReportSection {
        var lines: [String] = []

        for plant in plants.sorted(by: { $0.plantedAt < $1.plantedAt }) {
            lines.append(
                "\(plant.displayName) · \(plant.displayStrain) · \(plant.room?.name ?? "No room") · now \(plant.stage.title)"
            )
            let events = plant.sortedStageEvents
            if events.isEmpty {
                lines.append("  No stage changes recorded.")
            } else {
                for event in events {
                    let backfilled = event.isBackfilled ? " · backfilled" : ""
                    let note = event.note.isEmpty ? "" : " · \(event.note)"
                    lines.append("  \(Format.shortDate(event.date)) · \(event.stage.title)\(backfilled)\(note)")
                }
            }
        }

        if plants.isEmpty {
            lines.append("No plants are recorded.")
        }
        return GrowReportSection(id: "stages", title: "Stage timeline", lines: lines)
    }

    // MARK: Care

    private static func careSection(
        plants: [Plant],
        rooms: [Room],
        unit: UnitSystem
    ) -> GrowReportSection {
        var lines: [String] = []

        let feeds = rooms.flatMap(\.feedEvents).sorted { $0.date < $1.date }
        if feeds.isEmpty {
            lines.append("Feed and watering events: none recorded.")
        } else {
            let volumes = feeds.compactMap(\.volumeLiters)
            let totalVolume = volumes.isEmpty ? nil : volumes.reduce(0, +)
            lines.append("Feed and watering events: \(feeds.count)")
            if let totalVolume {
                lines.append("Total logged volume: \(Format.volume(totalVolume, unit: unit))")
            }
            lines.append(
                "Events with pH: \(feeds.filter { $0.phIn != nil || $0.phRunoff != nil }.count) · events with EC: \(feeds.filter { $0.ecIn != nil || $0.ecRunoff != nil }.count)"
            )
            if let last = feeds.last {
                lines.append("Last feed or watering: \(Format.shortDate(last.date))")
            }
        }

        let readings = rooms.flatMap(\.environmentReadings).sorted { $0.date < $1.date }
        if readings.isEmpty {
            lines.append("Environment readings: none recorded.")
        } else {
            let averageTemperature = CareLog.average(readings.map(\.temperatureC))
            let averageHumidity = CareLog.average(readings.map(\.humidityPercent))
            var summary = "Environment readings: \(readings.count)"
            if let averageTemperature {
                summary += " · average \(Format.temperature(averageTemperature, unit: unit))"
            }
            if let averageHumidity {
                summary += " · average \(String(format: "%.0f%%", averageHumidity)) humidity"
            }
            lines.append(summary)
            lines.append("Readings outside the room target: \(readings.filter(\.isAnyOutOfRange).count)")
            if let last = readings.last {
                lines.append("Last reading: \(Format.shortDate(last.date))")
            }
        }

        // `plants` is used to keep the section signature stable for future
        // per-plant summaries, and to state the plant count explicitly.
        lines.append("Plants in this report: \(plants.count)")
        return GrowReportSection(id: "care", title: "Feeding and environment summary", lines: lines)
    }

    // MARK: Training

    private static func trainingSection(plants: [Plant]) -> GrowReportSection {
        let sessions = plants.flatMap(\.trainingSessions).sorted { $0.date < $1.date }
        guard !sessions.isEmpty else {
            return GrowReportSection(id: "training", title: "Training", lines: ["None recorded."])
        }

        let lines = sessions.map { session -> String in
            var line = "\(Format.shortDate(session.date)) · \(session.method.title) · \(session.plant?.displayName ?? "No plant")"
            if let nodes = session.nodesAffected {
                line += " · \(nodes) nodes"
            }
            if !session.note.isEmpty {
                line += " · \(session.note)"
            }
            return line
        }
        return GrowReportSection(id: "training", title: "Training", lines: lines)
    }

    // MARK: Treatments

    private static func treatmentSection(plants: [Plant], rooms: [Room]) -> GrowReportSection {
        let treatments = (plants.flatMap(\.treatments) + rooms.flatMap(\.treatments))
            .sorted { $0.date < $1.date }
        guard !treatments.isEmpty else {
            return GrowReportSection(id: "treatments", title: "Treatments", lines: ["None recorded."])
        }

        let lines = treatments.map { treatment -> String in
            var line = "\(Format.shortDate(treatment.date)) · \(treatment.productName.isEmpty ? "Treatment" : treatment.productName)"
            if !treatment.dose.isEmpty {
                line += " · \(treatment.dose)"
            }
            line += " · \(treatment.plant?.displayName ?? treatment.room?.name ?? "No linked record")"
            if let end = treatment.withdrawalEndDate {
                line += " · withdrawal ends \(Format.shortDate(end))"
            }
            if !treatment.note.isEmpty {
                line += " · \(treatment.note)"
            }
            return line
        }
        return GrowReportSection(id: "treatments", title: "Treatments", lines: lines)
    }

    // MARK: Scouting

    private static func scoutingSection(plants: [Plant], rooms: [Room]) -> GrowReportSection {
        let checks = (plants.flatMap(\.scoutingChecks) + rooms.flatMap(\.scoutingChecks))
            .sorted { $0.date < $1.date }
        guard !checks.isEmpty else {
            return GrowReportSection(id: "scouting", title: "Scouting checks", lines: ["None recorded."])
        }

        let lines = checks.map { check -> String in
            var pieces = [Format.shortDate(check.date)]
            if !check.findings.isEmpty {
                pieces.append(check.findings.map(\.title).joined(separator: ", "))
            }
            pieces.append(check.plant?.displayName ?? check.room?.name ?? "No linked record")
            if !check.note.isEmpty {
                pieces.append(check.note)
            }
            return pieces.joined(separator: " · ")
        }
        return GrowReportSection(id: "scouting", title: "Scouting checks", lines: lines)
    }

    // MARK: Harvest

    private static func harvestSection(plants: [Plant], unit: UnitSystem) -> GrowReportSection {
        let harvested = plants.filter {
            $0.wetWeightGrams != nil
                || $0.dryWeightGrams != nil
                || $0.harvestDisposition != nil
                || $0.harvestedAt != nil
        }
        .sorted { $0.plantedAt < $1.plantedAt }

        guard !harvested.isEmpty else {
            return GrowReportSection(id: "harvest", title: "Harvest", lines: ["No harvest weights or dispositions recorded."])
        }

        var lines: [String] = []
        for plant in harvested {
            var pieces = [plant.displayName, plant.displayStrain]
            if let wet = plant.wetWeightGrams {
                pieces.append("wet \(Format.weight(wet, unit: unit))")
            }
            if let dry = plant.dryWeightGrams {
                pieces.append("dry \(Format.weight(dry, unit: unit))")
            }
            pieces.append("disposition: \(plant.harvestDisposition?.title ?? "not recorded")")
            if let gramsPerWatt = HarvestLog.gramsPerWatt(
                dryGrams: plant.dryWeightGrams,
                watts: plant.room?.lightWatts ?? 0
            ) {
                pieces.append(String(format: "%.2f g/W", gramsPerWatt))
            }
            lines.append(pieces.joined(separator: " · "))
        }
        lines.append("Dispositions are limited to retained, consumed at home and destroyed. The app has no sale, gift, transfer or distribution state.")
        return GrowReportSection(id: "harvest", title: "Harvest", lines: lines)
    }

    // MARK: Scope and journal

    private static func scopeSection(includeJournal: Bool, journal: [JournalEntry]) -> GrowReportSection {
        var lines: [String] = [
            "Cultivation journal entries are excluded unless you choose to include them.",
            "This report never includes a personal effect journal. Grow Companion does not have one.",
            LegalCopy.scope
        ]

        if includeJournal {
            let entries = journal.sorted { $0.createdAt < $1.createdAt }
            if entries.isEmpty {
                lines.append("Journal: no entries recorded.")
            } else {
                lines.append("Journal entries included by your choice: \(entries.count)")
                for entry in entries {
                    var line = "\(Format.shortDate(entry.createdAt)) · \(entry.kind.title)"
                    if let tag = entry.tag {
                        line += " · \(tag.title)"
                    }
                    if !entry.text.isEmpty {
                        line += " · \(entry.text)"
                    }
                    lines.append(line)
                }
            }
        }

        return GrowReportSection(id: "scope", title: "Scope and journal", lines: lines)
    }

    private static func jurisdictionLabel(profile: GrowProfile?, rule: JurisdictionRule?) -> String {
        if let rule {
            return "\(rule.stateName) (\(rule.jurisdictionCode))"
        }
        return profile?.stateName.isEmpty == false ? profile?.stateName ?? "Not set" : "Not set"
    }
}

enum GrowReportRenderer {
    static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 46

    static func pdf(from data: GrowReportData) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Grow Companion grow report",
            kCGPDFContextCreator as String: "Grow Companion"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        return renderer.pdfData { context in
            let ink = UIColor(white: 0.10, alpha: 1)
            let secondary = UIColor(white: 0.42, alpha: 1)
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .semibold)
            let headingFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 10.5, weight: .regular)
            let smallFont = UIFont.systemFont(ofSize: 8.5, weight: .regular)
            let contentWidth = pageSize.width - margin * 2
            let bottomLimit = pageSize.height - margin - 26

            var pageNumber = 0
            var y: CGFloat = margin

            func drawFooter() {
                let text = "Page \(pageNumber) · generated on this device · not legal advice"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: smallFont,
                    .foregroundColor: secondary
                ]
                (text as NSString).draw(
                    at: CGPoint(x: margin, y: pageSize.height - margin + 4),
                    withAttributes: attributes
                )
            }

            func beginPage() {
                if pageNumber > 0 { drawFooter() }
                context.beginPage()
                pageNumber += 1
                y = margin
                ("Grow Companion" as NSString).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: [.font: headingFont, .foregroundColor: secondary]
                )
                y += 22
            }

            func draw(_ text: String, font: UIFont, color: UIColor, after: CGFloat) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                let height = ceil(bounding.height)
                if y + height + after > bottomLimit {
                    beginPage()
                }
                (text as NSString).draw(
                    with: CGRect(x: margin, y: y, width: contentWidth, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                y += height + after
            }

            beginPage()

            draw("Grow report", font: titleFont, color: ink, after: 6)
            draw(
                "\(data.jurisdictionLabel) · \(Format.shortDate(data.generatedAt))",
                font: bodyFont,
                color: secondary,
                after: 4
            )
            draw(
                "Rule pack \(data.rulePackVersion) · verified \(RulePack.displayDate(data.rulePackVerifiedOn))",
                font: smallFont,
                color: secondary,
                after: 14
            )

            for section in data.sections {
                draw(section.title, font: headingFont, color: ink, after: 5)
                for line in section.lines {
                    draw(line, font: bodyFont, color: ink, after: 3)
                }
                y += 10
            }

            draw("Verification duty", font: headingFont, color: ink, after: 5)
            draw(data.verificationDuty, font: smallFont, color: secondary, after: 8)

            drawFooter()
        }
    }

    /// A neutral name: no plant, room or strain name is part of the file.
    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Grow-Report-\(formatter.string(from: date)).pdf"
    }

    static func writeTemporaryFile(pdf: Data, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdf.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
