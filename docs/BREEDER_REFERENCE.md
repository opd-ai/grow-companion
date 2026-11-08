# Breeder reference library

The strain library has always recorded a breeder name, an expected flowering
window and free-text lineage. This phase gives that a reference side: bundled
profiles per breeder, a per-cultivar lineage claim, and a screen that puts the
claim beside the grower's own finished cycles without mixing the two.

It is the remaining work of roadmap section 2.3. Everything is on device and
nothing is fetched: the profiles ship in the app, and the grower's results stay
in the SwiftData store.

## What ships

- **Breeder profiles.** `Services/BreederLibrary.swift` bundles a profile for
  every breeder used by `StrainCatalog.templates`: a summary, longer notes, an
  optional link to the breeder's own site, a source line and a review date. A
  profile is a value (`Models/BreederProfile.swift`), not a record, so no schema
  stage and no migration were needed.
- **Name matching.** `BreederLibrary.key(for:)` folds case and accents, turns
  `&` into `and`, drops punctuation and collapses whitespace. A strain whose
  breeder is typed `"  sensi   seeds "` points at the same profile as
  `"Sensi Seeds"`, which is how several strains share one breeder.
- **A library screen.** Strain library → *Breeder reference* lists the profiles
  with a search field and, for each, how many of the grower's strains point at
  it. A profile screen shows the notes, the source and review date, the links,
  and each matching strain with the claimed window, the grower's observed
  average and a sentence comparing the two.
- **Lineage per cultivar.** `CultivarLineage` attaches parent lines to one
  cultivar and breeder pair rather than to a breeder. Only the bundled templates
  with an existing claim appear: Blue Dream (documented), Jack Herer (disputed)
  and White Widow (documented). A header card, the profile screen and the strain
  detail repeat that lineages are disputed.
- **Claimed figures labelled.** The strain detail now says *Claimed* beside the
  flowering window and *Breeder's claim* in the timing card, and the editor's
  breeder field has a row of bundled breeders that fills the name in one tap.
- **No new stored type.** Export, backup, restore, delete-all and the data
  inventory are untouched by this phase: nothing new is stored.

## Data

| Type | What it holds |
| --- | --- |
| `BreederProfile` | name, summary, notes, links, source, review date |
| `BreederLink` | title and an https URL |
| `CultivarLineage` | cultivar, breeder, parent lines, claimed yield, lineage status, source |
| `BreederCultivarSummary` | claimed weeks, the grower's observed days and finished cycle count, and the comparison sentence |

The review date is 15 May 2025, the same date the bundled rule pack was
verified. There is no signed or remote content pack yet: the profiles are code.

## Decisions

- **Value types, not a `Breeder` entity.** Roadmap section 2.3 says breeder data
  is read-only reference content bundled now, updated through the signed content
  pipeline planned for the rules. The grower's own results already live on
  `Strain` and `Plant`, so a stored breeder record would add a migration and an
  export path without adding a fact the app does not already have. If the grower
  ever needs to edit a profile, that becomes an additive entity in its own
  stage.
- **Lineage belongs to a cultivar.** The previous code keyed parent lines by
  breeder, so every Humboldt strain inherited *Blueberry × Haze*. Claims now
  live on the cultivar and breeder pair, and a strain that is not a bundled
  template shows its own free text only.
- **Only existing claims are repeated.** The three bundled lineages are the
  strings the app already carried; new parent lines were not invented. The rest
  of the catalogue shows *Not documented* and asks the grower for their own
  notes.
- **Links only where known.** Sensi Seeds and Royal Queen Seeds carry an https
  link; the other profiles carry none rather than a guessed address.
- **The comparison never merges.** Claimed weeks and observed days are shown in
  separate lines, and the comparison sentence says which one the difference is
  measured from.

## Copy limits

The roadmap sets the tone for reference material: claims stay labelled, and no
cannabis product claim is presented as verified. `BreederLibraryTests` enforces
that the bundled summaries and lineages contain none of the words the project
treats as product claims (potency, THC, cannabinoid, lab test), that the caveats
are present, and that every profile has a source and the shared review date.

## Tests

`Grow CompanionTests/BreederLibraryTests.swift` covers:

- normalisation by case, accents, punctuation, spacing and `&`;
- lookup by any spelling, and nil for an unknown or empty name;
- profile coverage of every bundled template breeder, with unique names,
  complete copy and https-only links;
- search by name and by copy;
- lineage matching on both cultivar and breeder, the disputed Jack Herer claim,
  and that every lineage points at a bundled template;
- strain matching, sorting and counts;
- the claim/observed summary with no finished cycle, and the match, longer and
  shorter comparisons, including a zero claim;
- the copy limits above.

The app and test targets compile. This environment has no simulator, so the
suite is compiled but not executed here; CI runs it on an iPhone 17 simulator
when a build or pull request reaches `main`.

## Remaining work

- A stored, grower-editable breeder profile would need an additive model and its
  export, backup and inventory entries. There is no remote content pack: the
  reference ships with the app, because the app makes no network request.
- The catalogue is eleven breeders, matching the bundled templates. A grower's
  own breeder shows no profile until it is added to the bundle.
