//
//  EducationOnlyView.swift
//  Grow Companion
//
//  Shown when the user's jurisdiction does not permit personal home
//  cultivation: the rules stay readable, tracking stays off.
//

import SwiftUI

struct EducationOnlyView: View {
    let profile: GrowProfile

    @State private var showingChange = false

    private var rule: JurisdictionRule? { profile.rule }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Pill(
                            text: "Education only",
                            systemImage: "book.closed",
                            tint: Theme.amber,
                            fill: Theme.amberSoft
                        )
                        Text("Tracking is off")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text(LegalCopy.educationOnly)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(profile.jurisdictionLabel)
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                    .growCard()

                    if let rule {
                        RulesDetailView(rule: rule)
                    }

                    FederalNoticeCard()
                    VerificationDutyCard()

                    SecondaryButton("Change jurisdiction", systemImage: "mappin.and.ellipse") {
                        showingChange = true
                    }
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
    }
}
