//
//  Components.swift
//  Grow Companion
//
//  Shared building blocks: cards, pills, buttons, section headers and the
//  compliance ring.
//

import SwiftUI

// MARK: - Cards

struct CardBackground: ViewModifier {
    var fill: Color
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func growCard(fill: Color = Theme.surface, padding: CGFloat = 18, radius: CGFloat = Theme.cornerRadius) -> some View {
        modifier(CardBackground(fill: fill, padding: padding, radius: radius))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.sans(12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(Theme.secondaryInk)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pills

struct Pill: View {
    var text: String
    var systemImage: String?
    var tint: Color = Theme.primary
    var fill: Color = Theme.sageSoft

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(Theme.sans(12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(fill))
    }
}

struct StageBadge: View {
    var stage: PlantStage

    var body: some View {
        Pill(text: stage.shortTitle, systemImage: stage.systemImage)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var isEnabled: Bool = true
    var action: () -> Void

    init(_ title: String, systemImage: String? = nil, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(Theme.sans(17, weight: .semibold))
            }
            .foregroundStyle(Theme.onHero)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? Theme.primary : Theme.primary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(Theme.sans(15, weight: .semibold))
            }
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.primary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compliance ring

struct ComplianceRing: View {
    var counted: Int
    var limit: Int?
    var level: ComplianceLevel
    var size: CGFloat = 132

    private var progress: Double {
        guard let limit, limit > 0 else { return 0 }
        return min(Double(counted) / Double(limit), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.onHero.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.03, progress))
                .stroke(level.heroTint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(counted)")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.onHero)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("of \(limit.map(String.init) ?? "—")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.onHero.opacity(0.65))
                Text("plants")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Theme.onHeroSecondary)
                    .padding(.top, 4)
            }
            .padding(8)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(counted) of \(limit.map(String.init) ?? "no") plants counted, \(level.title)")
    }
}

// MARK: - Small rows

struct MetricLine: View {
    var label: String
    var value: String
    var tint: Color = Theme.onHero
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Theme.onHeroSecondary)
            Text(value)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(tint)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.onHeroSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stars

struct StarRatingView: View {
    var rating: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(index <= rating ? Theme.primary : Theme.tertiaryInk.opacity(0.6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}
