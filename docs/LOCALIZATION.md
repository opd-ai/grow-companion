# Localization status

The Spanish (Mexico) translation is being built in the app's String Catalog,
`Grow Companion/Resources/Localizable.xcstrings`. This file records the
mechanism, what is covered, the glossary to keep the remaining batches
consistent, and the rules a translator must follow.

## Mechanism, verified

A `.xcstrings` catalog placed in the app's synchronized `Resources` folder is
compiled into `es.lproj/Localizable.strings` by an ordinary `xcodebuild` build.
No project-file edit, no variant group and no `knownRegions` change are needed:

```
xcodebuild build -project "Grow Companion.xcodeproj" -scheme "Grow Companion" \
  -destination "generic/platform=iOS" -derivedDataPath "$HOME/build-dd"
ls "$HOME/build-dd/Build/Products/Debug-iphoneos/Grow Companion.app" | grep lproj
```

That prints `es.lproj`, and `plutil -convert json` on the compiled
`Localizable.strings` shows the translated keys. Plural entries are compiled into
`Localizable.stringsdict` beside it, not into the `.strings` file. Keys that are
not in the catalog fall back to English, so an incomplete catalog is safe and
can grow batch by batch.

## What is covered

The catalog holds 1,456 Spanish (Mexico) strings and is a complete draft of
the app's user-facing copy, screen by screen, including every value the app
formats with a variable:

- the shared vocabulary: stage names, short names and the seven stage-guidance
  paragraphs; plant origin; harvest disposition and explanations; room types;
  residence and experience levels; journal kinds; observation tags; strain
  types; training methods; drying phases and profiles; burp modes; stem snap;
  light fixtures and their cited guidance; sensor transports; breeder lineage;
- app chrome: tab labels, `Save`, `Cancel`, `Done`, `Delete`, `Edit`, `Close`,
  `Not recorded`, `Not specified`, `OK`, `Continue`, `Retry`, units and their
  summaries;
- every screen: Home, onboarding and lock, plants and plant detail, care
  (environment, feeding, calibration, reminders, feed schedules), journal,
  garden timeline and photos, harvest, drying and curing, cycle comparison,
  strains, equipment, compliance and rule-review interface labels, settings
  (app lock, notifications, backup, export and delete, sharing, sync and
  privacy, sensors, reports, widget), the grow calendar, Quick Log, calculators,
  sharing, the education library and the service-level error and status copy.
- the verification-duty card's notice that legal text is still English.

**How the variable strings were found.** A string built with interpolation
(`Text("\(count) plants")`) is looked up by its compiled format pattern
(`"%lld plants"`), not by the text in the source, so guessing the pattern
produces keys that silently never match. They were read from the build instead:
compiling the app writes one `.stringsdata` file per source file into the
derived data, and each holds the exact keys the app will ask for, with their
format specifiers. Those 148 patterns are in the catalog now.

**What is deliberately not in the catalog.** A build asks for 853 such keys.
Twenty-five get no entry because Spanish and English read identically:
placeholders (`%@`, `%@ · %@`, `%lld`), separators and arrows (`·`, `–`, `→`),
unit symbols (`W`, `g`, `oz`, `cm`, `ml/L`, `m²`, `sq ft`), plain numbers, and
`Grow Companion %@`.

**Plurals.** Twenty-three entries carry `one`/`other` plural variations, which a
build compiles into `es.lproj/Localizable.stringsdict`: counts (`%lld days`,
`%lld overdue`, `%lld records`), the record, journal, photo and calculation
lines, and the flowering warnings, whose verb has to agree with the number.
Where one line holds two counts the first one selects the plural form. A few
source lines append an English plural suffix to a noun (`"\(count) plant\(count
== 1 ? "" : "s")"`, compiled to `"%lld plant%@"`); Spanish forms those plurals
with a trailing `s` too, so the suffix still works, and where it cannot
(`entr` + `y`/`ies`) the entry supplies the whole noun and its own forms.

Legal and rule text — `LegalCopy`, `RulePack` citations, rule summaries,
jurisdiction data and the federal notice — stays English on purpose. Rule 4
below, and the in-app notice, explain why.

## Model, service and view copy

Copy held in a model or a service is a plain `String`, and `Text(stage.title)`
treats a `String` as verbatim text, so the catalog never applied to it. That is
fixed: the display properties in `Models/Enums.swift`, `Models/DryingSession.swift`,
`Models/LightDistance.swift`, `Models/SensorDevice.swift`,
`Models/BreederContext.swift`, `Models/ShareGrant.swift`, and the display and
error copy in `Services/` (`LightSchedule`, `GardenTimeline`, `CareLog`,
`CareDigest`, `NotificationSettings`, `GrowGoals`, `QuickLog`, `GrowCalendar`,
`CareNotifications`, `EducationLibrary`, `AppLock`, `HarvestForecast`,
`HarvestLog`, `TrainingLog`, `TreatmentLog`, `EquipmentLog`, `Format`,
`PhotoTimeline`, `SharePayload`, `SensorConnectionService`, `StoreBoot`,
`ComplianceEngine`, `StrainInsights`, `ExportService`, `SecureEnvelope`,
`SharePackageService`, `DeviceKeyStore`, `PlantRemovalService`) now go through
`String(localized:)`, so the existing translations apply. Two kinds of literal
are deliberately untouched: `rawValue`, `symbolName` and file names, which must
not move, and the rule-engine labels in `RuleEvaluationEvent` and
`JurisdictionRule`, which are legal copy.

The widget is a separate bundle and cannot read the app's catalog, so the app
now writes the localized headline and overdue line into the shared snapshot and
the widget renders them verbatim; the widget gallery's own name and description
stay English.

A build confirmed the result: of 1,130 keys the compiled app asks for, 27 get no
entry, and every one of them is a placeholder, a unit symbol, a bare number or
`Grow Companion %@` — text that reads identically in both languages.

**View copy.** The copy computed inside views — home summaries and stage
sentences, the cycle comparison, drying and harvest calendar, anomaly review,
feed schedules, room sections, calculators, backup, strain detail and library
— now goes through `String(localized:)` too, including the date-and-time
phrases and the accessibility labels. A build then asks for 1,218 keys and every
one of them except 27 placeholders, unit symbols, bare numbers and
`Grow Companion %@` has Spanish text.

## Glossary (use these exact words in later batches)

| English | Spanish |
| --- | --- |
| grow, cultivation | cultivo |
| grower | cultivador |
| room, grow space | sala |
| tent / closet | carpa / armario |
| strain, cultivar | variedad |
| plant | planta |
| seedling | plántula |
| clone, cutting | esqueje, esqueje sin enraizar |
| vegetative / flowering | vegetativo / floración |
| flowering weeks | semanas de floración |
| canopy | dosel |
| feed, watering | riego (both; "alimentación" only for nutrients) |
| runoff | drenaje |
| reservoir | depósito |
| harvest | cosecha |
| wet / dry weight | peso húmedo / peso seco |
| drying / curing / burping | secado / curado / airear los frascos |
| trimming, training | poda, entrenamiento |
| scouting check | inspección |
| treatment, withdrawal | tratamiento, carencia |
| reminder | recordatorio |
| threshold, target range | umbral, rango objetivo |
| jurisdiction, limit | jurisdicción, límite |
| compliance | cumplimiento |
| rule pack | paquete de normas |
| backup, restore, export | copia de seguridad, restaurar, exportar |
| app lock | bloqueo de la app |

Keep `R/O`, `pH`, `EC`, `PPFD`, `VPD`, `LED`, `HPS`, `CMH`, `SCROG`, `Wi-Fi`
and unit symbols (`g`, `kg`, `oz`, `°C`, `°F`, `m²`, `ft²`, `L`, `gal`) as they
are.

## Rules for the remaining batches

1. **The key is the exact source literal.** Copy it from the source file, not
   from memory. A key that does not match simply stays English.
2. **Variable strings use the compiled pattern, not the source text.** Copy the
   key from a build's `.stringsdata` files, never from the source interpolation.
   A value must keep the same specifiers, in the same order; the catalog test
   fails otherwise.
3. **Plural strings need plural variations.** Any key with a count gets a
   `plural` variation (`one`/`other`) in Spanish, not a single value.
4. **Legal, rule and verification text stays English.** Do not translate
   `LegalCopy`, `RulePack` citations, rule summaries, jurisdiction data or the
   federal notice until the *Spanish legal copy* passes its own localisation
   review. The general legal review of the shipped English copy is complete
   (`docs/ROADMAP.md` section 1.1); it did not clear a translation of it.
   `Services/Localization.swift` shows a notice while the app is in Spanish so
   this is explained in the product.
5. **No machine translation into the catalog unreviewed.** The draft in the
   catalog is for review; a reviewer signs off each batch before release.
6. **Check the layout.** Spanish runs 15–25% longer. Every batch needs a device
   pass at the largest Dynamic Type size; the build alone cannot prove nothing
   clips.

## Verification

`Grow CompanionTests/LocalizationCatalogTests.swift` reads this catalog from the
source tree and fails the build when:

- an entry has no Spanish text, or an empty value;
- a Spanish value changes, drops or reorders its key's format specifiers (a
  mistyped `%@` is a runtime format crash, not a cosmetic slip);
- a plural entry lacks `one` or `other`.

A value may leave out a trailing `%@` the English plural-suffix trick used,
because Spanish supplies the whole noun instead.

## Remaining batches

The interface draft is complete, variable strings and plurals included. What is
left:

1. **Legal and rule copy**, once the legal localisation review in
   `docs/ROADMAP.md` 7.8 is signed off. Until then the English text and the
   notice in the verification-duty card are the correct state.
2. **A translator review and a device pass** at the largest Dynamic Type size,
   because Spanish runs 15–25% longer and the build alone cannot prove nothing
   clips.
