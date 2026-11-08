//
//  HarvestPlanningView.swift
//  Grow Companion
//
//  Read-only harvest windows from existing stage history and flowering figures.
//

import SwiftUI
import SwiftData

struct HarvestPlanningView: View {
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]

    private var forecasts: [HarvestForecast] {
        HarvestCalendar.forecasts(for: plants)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                legend
                if forecasts.isEmpty {
                    emptyState
                } else {
                    nextUpCard
                    forecastList
                }
                note
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Harvest planning")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Forecast windows for plants currently in flower, based on your records.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Theme.sage, title: "Forecast window")
            legendItem(color: Theme.amber, title: "Overrun")
        }
        .font(Theme.sans(11, weight: .semibold))
        .foregroundStyle(Theme.secondaryInk)
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(title)
        }
    }

    private var nextUpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Next up", subtitle: "Most likely finish first")
            ForEach(Array(forecasts.prefix(3))) { forecast in
                NavigationLink {
                    PlantDetailView(plant: forecast.plant)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: forecast.isOverrun ? "exclamationmark.triangle.fill" : "calendar")
                            .foregroundStyle(forecast.isOverrun ? Theme.amber : Theme.primary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(forecast.plant.displayName)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(forecast.plant.room?.name ?? "Room not recorded") · Flower week \(forecast.currentWeek)")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        Spacer()
                        Text(forecast.isOverrun ? "Overrun" : forecast.timingText)
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(forecast.isOverrun ? Theme.amber : Theme.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .growCard(fill: Theme.sageSoft)
    }

    private var forecastList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Flowering plants", subtitle: "Tap a plant to review its record")
            ForEach(forecasts) { forecast in
                NavigationLink {
                    PlantDetailView(plant: forecast.plant)
                } label: {
                    forecastRow(forecast)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func forecastRow(_ forecast: HarvestForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(forecast.plant.displayName)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(forecast.plant.room?.name ?? "Room not recorded") · \(forecast.plant.displayStrain)")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                if forecast.isOverrun {
                    Pill(text: "Overrun", systemImage: "exclamationmark.triangle.fill", tint: Theme.amber, fill: Theme.amberSoft)
                } else {
                    Pill(text: forecast.timingText.replacingOccurrences(of: "· ", with: ""), systemImage: "clock", tint: Theme.primary, fill: Theme.sageSoft)
                }
            }

            HStack(spacing: 0) {
                dateBlock("Window opens", forecast.windowStart)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.tertiaryInk)
                Spacer()
                dateBlock("Likely finish", forecast.mostLikelyDate)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.tertiaryInk)
                Spacer()
                dateBlock("Window ends", forecast.windowEnd)
            }

            HStack {
                Image(systemName: "info.circle")
                Text(forecast.sourceText)
                if forecast.source == .observed {
                    Text("· \(forecast.sampleCount) cycle\(forecast.sampleCount == 1 ? "" : "s")")
                }
                Spacer()
            }
            .font(Theme.sans(11))
            .foregroundStyle(Theme.tertiaryInk)
        }
        .growCard(padding: 15, radius: 20)
    }

    private func dateBlock(_ label: String, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Theme.sans(10, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
            Text(Format.shortDate(date))
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Theme.primary)
            Text("No flowering plants to forecast")
                .font(Theme.serif(22))
                .foregroundStyle(Theme.ink)
            Text("When a plant enters flower, its stage history and the best available flowering figure will appear here.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.sageSoft)
    }

    private var note: some View {
        Text("Forecasts are guidance only. The app uses your observed flowering duration when available, otherwise the breeder's figure, and does not change any plant record.")
            .font(Theme.sans(11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
