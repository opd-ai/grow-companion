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

That prints `es.lproj`, and `plutil -convert json` on the compiled file shows the
translated keys. Keys that are not in the catalog fall back to English, so an
incomplete catalog is safe and can grow batch by batch.

## What is covered

Batch 1 (shipped): the shared vocabulary and chrome — 159 keys.

- Stage names and short names (`Seed`, `Veg`, `Flowering`, `Curing`, …) and the
  seven stage guidance paragraphs.
- Plant origin, harvest disposition and the three disposition explanations.
- Room types, residence types, experience levels, journal kinds, observation
  tags, strain types, training methods, drying phases, drying profiles, burp
  modes, stem snap states, light fixtures and their cited guidance, sensor
  transports, breeder lineage states.
- App chrome: tab labels, `Save`, `Cancel`, `Done`, `Delete`, `Edit`, `Close`,
  `Not recorded`, `Not specified`, `Metric`/`Imperial` and their unit summaries.
- The Home screen's visible copy and its accessibility labels, plus the
  verification-duty note that explains that legal text is still English.

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
2. **Interpolated strings are skipped on purpose.** `Text("\(count) plants")`
   has a compiled format key (`"%lld plants"`), not the source text. They need
   the compiled pattern; leaving them English is safe. They are listed below so
   the next batch can pick them up from the built `.strings` file.
3. **Plural strings need plural variations.** Any key with a count gets a
   `plural` variation (`one`/`other`) in Spanish, not a single value.
4. **Legal, rule and verification text stays English.** Do not translate
   `LegalCopy`, `RulePack` citations, rule summaries, jurisdiction data or the
   federal notice until the legal localisation review in `docs/ROADMAP.md` 7.8
   is signed off. `Services/Localization.swift` shows a notice while the app is
   in Spanish so this is explained in the product.
5. **No machine translation into the catalog unreviewed.** The draft in the
   catalog is for review; a reviewer signs off each batch before release.
6. **Check the layout.** Spanish runs 15–25% longer. Every batch needs a device
   pass at the largest Dynamic Type size; the build alone cannot prove nothing
   clips.

## Remaining batches

Screens still in English, in the order they should be translated:

1. Onboarding (`OnboardingFlow`), lock overlay, store recovery.
2. Care: room sections, environment/feed/calibration sheets, reminder editor,
   feed schedules.
3. Plants: add plant, plant detail, training, treatments, scouting.
4. Journal, garden timeline, photo timeline and compare.
5. Harvest: calendar, drying, curing, cycle comparison.
6. Strains and equipment.
7. Compliance and rules screens (interface labels only, see rule 4).
8. Settings: app lock, notifications, backup, data controls, sharing, sync,
   sensors, reports, widget.
9. Quick Log, calculators, weekly recap, room comparison, performance report.
10. Service copy: error messages in `ExportService`, `BackupService`,
    `StoreBoot`, `AppLock`, notification titles and bodies, the widget's
    `configurationDisplayName` and `description`.

The interpolated strings from batch 1's files that still need the compiled
format keys: plant and room counts, "N of M plants counted", the compliance
level sentences, `Format.dayCount` and every `Text` that interpolates a
record's own name.
