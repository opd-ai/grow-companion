//
//  JurisdictionData.swift
//  Grow Companion
//
//  The bundled rule pack. Human-reviewed, dated and cited; the app shows each
//  rule's review date and source, warns when a pack is older than 90 days, and
//  always tells the user to verify the current law.
//
//  Limits below are the commonly reported adult-use (or medical, where noted)
//  home-cultivation limits at the pack's review date. They are a starting
//  point for the user's own verification, not legal advice.
//

import Foundation

enum JurisdictionData {
    private static let ncslURL = "https://www.ncsl.org/civil-and-criminal-justice/state-cannabis-laws"

    static let rules: [JurisdictionRule] = [
        // MARK: Allowed with registration or medical conditions

        JurisdictionRule(
            stateCode: "AK",
            stateName: "Alaska",
            plantLimit: 6,
            limitScope: .person,
            countedStages: [.clone, .veg, .flower],
            countsClones: true,
            countingNote: "Counts every plant you keep at home, clones included. No more than three may be mature or flowering at once.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to six plants at home, three of them mature, and keep up to one ounce of flower.",
            citation: "Alaska Stat. § 17.38.020",
            sourceURL: "https://www.commerce.alaska.gov/web/amco/",
            effectiveOn: "2015-02-24"
        ),
        JurisdictionRule(
            stateCode: "AZ",
            stateName: "Arizona",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. A household with two or more adults may keep up to twelve plants.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to six plants each, twelve per household, and keep up to one ounce of flower.",
            citation: "Ariz. Rev. Stat. § 36-2802",
            sourceURL: "https://www.azdhs.gov/licensing/medical-marijuana/",
            effectiveOn: "2020-11-30"
        ),
        JurisdictionRule(
            stateCode: "CA",
            stateName: "California",
            plantLimit: 6,
            limitScope: .residence,
            countingNote: "Counts every plant in veg and flower. Six is a cap per residence for adults 21 and over, no matter how many adults live there.",
            possessionLimitGrams: 28.5,
            canopyLimitSqM: 9.3,
            summary: "Adults 21 and over may grow up to six plants per residence and keep up to 28.5 g of flower. Cities and counties can ban or restrict cultivation, so check your local code.",
            citation: "Cal. Health & Safety Code §§ 11362.1–11362.2",
            sourceURL: "https://cannabis.ca.gov/",
            effectiveOn: "2016-11-09"
        ),
        JurisdictionRule(
            stateCode: "CO",
            stateName: "Colorado",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. No more than three may be mature or flowering, and a household of two or more adults may keep up to twelve.",
            possessionLimitGrams: 56.7,
            summary: "Adults 21 and over may grow up to six plants each, three mature, up to twelve per household, and keep two ounces of flower.",
            citation: "Colo. Rev. Stat. § 18-18-406",
            sourceURL: "https://cannabis.colorado.gov/",
            effectiveOn: "2012-12-10"
        ),
        JurisdictionRule(
            stateCode: "CT",
            stateName: "Connecticut",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to three mature and three immature plants per adult, and no more than twelve plants per household.",
            possessionLimitGrams: 141.7,
            summary: "Adults 21 and over may grow up to six plants each (three mature), twelve per household, and keep up to five ounces at home.",
            citation: "Conn. Gen. Stat. § 21a-421",
            sourceURL: "https://portal.ct.gov/cannabis",
            effectiveOn: "2023-07-01"
        ),
        JurisdictionRule(
            stateCode: "DE",
            stateName: "Delaware",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to six plants per adult and twelve per household, with a limit on how many may be mature.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to six plants each and keep up to one ounce of flower.",
            citation: "Del. Code tit. 4, ch. 53 (2023)",
            sourceURL: "https://dhss.delaware.gov/dhss/dph/medicalmarijuana/",
            effectiveOn: "2023-04-21"
        ),
        JurisdictionRule(
            stateCode: "DC",
            stateName: "District of Columbia",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to three mature and three immature plants per adult, with a twelve-plant cap per household.",
            possessionLimitGrams: 56.7,
            summary: "Adults 21 and over may grow up to six plants each (three mature), twelve per household, and keep up to two ounces of flower.",
            citation: "D.C. Code § 48-904.01(a)(1)(B)",
            sourceURL: "https://abca.dc.gov/",
            effectiveOn: "2015-02-26"
        ),
        JurisdictionRule(
            stateCode: "HI",
            stateName: "Hawaii",
            plantLimit: 10,
            limitScope: .person,
            countedStages: [.clone, .veg, .flower],
            countsClones: true,
            countingNote: "Counts every plant kept, clones included. Only registered medical patients may cultivate at home.",
            possessionLimitGrams: 113.4,
            medicalCardRequired: true,
            registrationRequired: true,
            registrationNote: "You must be a registered medical cannabis patient (or an approved caregiver) in the state program.",
            summary: "Registered medical cannabis patients may grow up to ten plants in a locked, enclosed space and keep up to four ounces.",
            citation: "Haw. Rev. Stat. § 329-123",
            sourceURL: "https://health.hawaii.gov/medicalcannabis/",
            effectiveOn: "2015-01-01"
        ),
        JurisdictionRule(
            stateCode: "IL",
            stateName: "Illinois",
            plantLimit: 5,
            limitScope: .person,
            countedStages: [.clone, .veg, .flower],
            countsClones: true,
            countingNote: "Counts every plant kept. Only registered medical patients may cultivate, in an enclosed and locked space.",
            possessionLimitGrams: 70.9,
            indoorAllowed: true,
            outdoorAllowed: false,
            medicalCardRequired: true,
            registrationRequired: true,
            registrationNote: "Home cultivation is limited to registered medical cannabis patients.",
            summary: "Registered medical cannabis patients may grow up to five plants indoors in a locked space and keep 2.5 ounces. Adult-use home cultivation is not permitted.",
            citation: "410 ILCS 130/25",
            sourceURL: "https://idfpr.illinois.gov/",
            effectiveOn: "2014-01-01"
        ),
        JurisdictionRule(
            stateCode: "ME",
            stateName: "Maine",
            plantLimit: 12,
            limitScope: .person,
            countedStages: [.clone, .veg, .flower],
            countsClones: true,
            countingNote: "Counts every plant you keep, including immature plants. No more than six may be mature or flowering, and households have a cap.",
            possessionLimitGrams: 70.9,
            summary: "Adults 21 and over may grow up to six mature plants and twelve plants in total, and keep 2.5 ounces of flower.",
            citation: "Me. Stat. tit. 28-B, § 1502",
            sourceURL: "https://www.maine.gov/dafs/ocp/",
            effectiveOn: "2017-01-30"
        ),
        JurisdictionRule(
            stateCode: "MD",
            stateName: "Maryland",
            plantLimit: 2,
            limitScope: .residence,
            countingNote: "Counts every plant at the residence. Two plants per household for adults; registered medical patients may grow a limited additional number.",
            possessionLimitGrams: 42.5,
            summary: "Adults 21 and over may grow up to two plants per household and keep up to 1.5 ounces. Medical patients have a separate allowance.",
            citation: "Md. Code, Alcoh. Bev. & Cannabis § 36-101 et seq.",
            sourceURL: "https://cannabis.maryland.gov/",
            effectiveOn: "2023-07-01"
        ),
        JurisdictionRule(
            stateCode: "MA",
            stateName: "Massachusetts",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to six plants per adult, with a twelve-plant cap per household.",
            possessionLimitGrams: 283.5,
            summary: "Adults 21 and over may grow up to six plants each, twelve per household, and keep up to ten ounces of flower at home.",
            citation: "Mass. Gen. Laws ch. 94G, § 7",
            sourceURL: "https://masscannabiscontrol.com/",
            effectiveOn: "2016-12-15"
        ),
        JurisdictionRule(
            stateCode: "MI",
            stateName: "Michigan",
            plantLimit: 12,
            limitScope: .residence,
            countedStages: [.clone, .veg, .flower],
            countsClones: true,
            countingNote: "Counts every plant at the residence. Up to twelve plants per household, and a registered caregiver may grow more for patients.",
            possessionLimitGrams: 283.5,
            summary: "Households may grow up to twelve plants and keep up to ten ounces of flower. Local ordinances can restrict where plants are kept.",
            citation: "Mich. Comp. Laws § 333.27954",
            sourceURL: "https://www.michigan.gov/cra",
            effectiveOn: "2018-12-06"
        ),
        JurisdictionRule(
            stateCode: "MN",
            stateName: "Minnesota",
            plantLimit: 8,
            limitScope: .residence,
            countingNote: "Counts plants in veg and flower. Up to eight plants per residence, no more than four of them flowering.",
            possessionLimitGrams: 907,
            summary: "Adults 21 and over may grow up to eight plants at home, four of them flowering, and keep up to two pounds of flower.",
            citation: "Minn. Stat. ch. 342 (2023)",
            sourceURL: "https://mn.gov/ocm/",
            effectiveOn: "2023-08-01"
        ),
        JurisdictionRule(
            stateCode: "MO",
            stateName: "Missouri",
            plantLimit: 6,
            limitScope: .person,
            countedStages: [.clone, .veg, .flower],
            countsClones: true,
            countingNote: "Counts every plant kept. Up to six flowering plants and six non-flowering plants for registered medical patients.",
            possessionLimitGrams: 113.4,
            medicalCardRequired: true,
            registrationRequired: true,
            registrationNote: "Home cultivation requires a state medical cannabis registration.",
            summary: "Registered medical patients may grow up to six flowering plants at home and keep up to four ounces in a secure space.",
            citation: "Mo. Rev. Stat. § 1.020 (Art. XIV, 2022)",
            sourceURL: "https://health.mo.gov/safety/medical-marijuana/",
            effectiveOn: "2022-12-08"
        ),
        JurisdictionRule(
            stateCode: "MT",
            stateName: "Montana",
            plantLimit: 4,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to four mature plants per adult and eight per household.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to four mature plants each, eight per household, and keep one ounce of flower.",
            citation: "Mont. Code Ann. § 16-12-106",
            sourceURL: "https://dphhs.mt.gov/cannabis",
            effectiveOn: "2021-01-01"
        ),
        JurisdictionRule(
            stateCode: "NV",
            stateName: "Nevada",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to six per adult and twelve per household. Some ZIP codes with no dispensary allow a higher count.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to six plants each, twelve per household, and keep one ounce of flower.",
            citation: "Nev. Rev. Stat. ch. 678D",
            sourceURL: "https://ccb.nv.gov/",
            effectiveOn: "2017-01-01"
        ),
        JurisdictionRule(
            stateCode: "NM",
            stateName: "New Mexico",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to six mature plants per adult and twelve per household.",
            possessionLimitGrams: 56.7,
            summary: "Adults 21 and over may grow up to six mature plants each, twelve per household, and keep up to two ounces of flower.",
            citation: "N.M. Stat. Ann. § 26-2C-1 et seq.",
            sourceURL: "https://www.rld.nm.gov/cannabis/",
            effectiveOn: "2022-06-29"
        ),
        JurisdictionRule(
            stateCode: "NY",
            stateName: "New York",
            plantLimit: 3,
            limitScope: .person,
            countingNote: "Counts mature plants in veg and flower. Adults may keep three mature and three immature plants each, with a six-mature cap per household.",
            possessionLimitGrams: 85,
            summary: "Adults 21 and over may grow up to three mature and three immature plants each (six mature per household) and keep up to three ounces of flower.",
            citation: "N.Y. Cannabis Law § 222",
            sourceURL: "https://cannabis.ny.gov/",
            effectiveOn: "2021-03-31"
        ),
        JurisdictionRule(
            stateCode: "OH",
            stateName: "Ohio",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to six per adult and twelve per household.",
            possessionLimitGrams: 70.9,
            summary: "Adults 21 and over may grow up to six plants each, twelve per household, and keep 2.5 ounces of flower.",
            citation: "Ohio Rev. Code ch. 3780",
            sourceURL: "https://cannabis.ohio.gov/",
            effectiveOn: "2023-12-07"
        ),
        JurisdictionRule(
            stateCode: "OR",
            stateName: "Oregon",
            plantLimit: 4,
            limitScope: .residence,
            countingNote: "Counts plants in veg and flower. Four plants per residence, regardless of how many adults live there.",
            possessionLimitGrams: 227,
            summary: "Adults 21 and over may grow up to four plants per residence and keep up to eight ounces of flower at home.",
            citation: "Or. Rev. Stat. § 475B.301",
            sourceURL: "https://www.oregon.gov/olcc/pages/cannabis.aspx",
            effectiveOn: "2015-07-01"
        ),
        JurisdictionRule(
            stateCode: "RI",
            stateName: "Rhode Island",
            plantLimit: 6,
            limitScope: .person,
            countingNote: "Counts plants in veg and flower. Up to three mature and three immature plants per adult, with a household cap.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to six plants each (three mature) and keep one ounce of flower.",
            citation: "R.I. Gen. Laws § 21-28.11-5",
            sourceURL: "https://dbr.ri.gov/divisions/cannabis",
            effectiveOn: "2022-12-01"
        ),
        JurisdictionRule(
            stateCode: "VT",
            stateName: "Vermont",
            plantLimit: 6,
            limitScope: .residence,
            countingNote: "Counts plants in veg and flower. Up to two mature and four immature plants per adult, with a household cap of six mature plants.",
            possessionLimitGrams: 28.3,
            summary: "Adults 21 and over may grow up to two mature and four immature plants each, and keep one ounce of flower.",
            citation: "Vt. Stat. Ann. tit. 18, § 4230",
            sourceURL: "https://canncontrol.vermont.gov/",
            effectiveOn: "2018-07-01"
        ),
        JurisdictionRule(
            stateCode: "VA",
            stateName: "Virginia",
            plantLimit: 4,
            limitScope: .residence,
            countingNote: "Counts plants in veg and flower. Four plants per household, grown indoors or in a structure not visible from public view.",
            possessionLimitGrams: 28.3,
            outdoorAllowed: false,
            summary: "Adults 21 and over may grow up to four plants per household out of public view and keep one ounce of flower.",
            citation: "Va. Code § 4.1-1101",
            sourceURL: "https://cca.virginia.gov/",
            effectiveOn: "2021-07-01"
        ),

        // MARK: Home cultivation not permitted

        JurisdictionRule(
            stateCode: "AL",
            stateName: "Alabama",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Alabama does not allow personal home cultivation of cannabis. Medical use runs through licensed dispensaries only.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "AR",
            stateName: "Arkansas",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Arkansas does not allow personal home cultivation, including for medical patients. Cultivation is licensed only.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "FL",
            stateName: "Florida",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Florida permits medical cannabis use but not home cultivation. Cultivation is licensed only.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "GA",
            stateName: "Georgia",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Georgia's medical program is low-THC oil only and does not allow home cultivation of cannabis plants.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "ID",
            stateName: "Idaho",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Idaho has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "IN",
            stateName: "Indiana",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Indiana does not allow personal home cultivation of cannabis.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "IA",
            stateName: "Iowa",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Iowa's medical program does not allow home cultivation of cannabis plants.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "KS",
            stateName: "Kansas",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Kansas has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "KY",
            stateName: "Kentucky",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Kentucky's medical program does not allow home cultivation of cannabis plants.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "LA",
            stateName: "Louisiana",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Louisiana permits medical cannabis but not personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "MS",
            stateName: "Mississippi",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Mississippi's medical program does not permit personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "NE",
            stateName: "Nebraska",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Nebraska does not permit personal home cultivation of cannabis.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "NH",
            stateName: "New Hampshire",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "New Hampshire's medical program does not allow personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "NJ",
            stateName: "New Jersey",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "New Jersey permits adult-use sales and medical use but not personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "NC",
            stateName: "North Carolina",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "North Carolina has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "ND",
            stateName: "North Dakota",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "North Dakota's medical program does not allow personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "OK",
            stateName: "Oklahoma",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted without a commercial licence.",
            summary: "Oklahoma licences commercial growers but does not allow personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "PA",
            stateName: "Pennsylvania",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Pennsylvania permits medical cannabis but not personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "SC",
            stateName: "South Carolina",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "South Carolina has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "SD",
            stateName: "South Dakota",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "South Dakota's medical program does not allow personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "TN",
            stateName: "Tennessee",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Tennessee has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "TX",
            stateName: "Texas",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Texas restricts medical cannabis to low-THC products and does not allow home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "UT",
            stateName: "Utah",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Utah permits medical cannabis through licensed pharmacies but not personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "WA",
            stateName: "Washington",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — Washington does not allow home cultivation for personal use.",
            summary: "Washington permits adult-use sales but does not allow home cultivation of cannabis for personal use.",
            citation: "Wash. Rev. Code ch. 69.50",
            sourceURL: "https://lcb.wa.gov/",
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "WV",
            stateName: "West Virginia",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "West Virginia permits medical cannabis but not personal home cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "WI",
            stateName: "Wisconsin",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Wisconsin has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        ),
        JurisdictionRule(
            stateCode: "WY",
            stateName: "Wyoming",
            cultivable: false,
            plantLimit: nil,
            countingNote: "Not applicable — home cultivation is not permitted by state law.",
            summary: "Wyoming has no legal cannabis program and prohibits personal cultivation.",
            citation: "State cannabis law summary (NCSL)",
            sourceURL: ncslURL,
            cityOverrideWarning: false
        )
    ]
}
