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

The catalog holds 986 Spanish (Mexico) strings and is a complete draft of the
app's user-facing copy, screen by screen:

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

A coverage check against the source finds 986 of 999 non-interpolated UI
literals covered. The 13 that are not are deliberately left as source
fragments: unit symbols (`g`, `oz`, `cm`, `W`), the arrow, separator and chevron
glyphs, and short words (`dry`, `plants`, `No dry`) that the code assembles into
a sentence at runtime.

Interpolated strings (`Text("\(count) plants")`) are not in the catalog on
purpose: their key is the compiled format pattern (`"%lld plants"`), not the
source text. They fall back to English, and the next pass reads the patterns
from the built `Localizable.strings` and adds them with plural variations.

Legal and rule text — `LegalCopy`, `RulePack` citations, rule summaries,
jurisdiction data and the federal notice — stays English on purpose. Rule 4
below, and the in-app notice, explain why.

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

## Remaining batches

The interface draft is complete. What is left:

1. **Interpolated strings.** Read the compiled `es.lproj/Localizable.strings`
   from a build, take the format patterns (`"%lld plants"`, `"target %@"`, …)
   and add each to the catalog with Spanish values and plural variations.
2. **Legal and rule copy**, once the legal localisation review in
   `docs/ROADMAP.md` 7.8 is signed off. Until then the English text and the
   notice in the verification-duty card are the correct state.
3. **A translator review and a device pass** at the largest Dynamic Type size,
   because Spanish runs 15–25% longer and the build alone cannot prove nothing
   clips.
