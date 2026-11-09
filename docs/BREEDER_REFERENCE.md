# Breeder reference library

The strain library has always recorded a breeder name, an expected flowering
window and free-text lineage. This phase gives that a reference side: bundled
profiles per breeder, a per-cultivar lineage claim, and a screen that puts the
claim beside the grower's own finished cycles without mixing the two.

It is the remaining work of roadmap section 2.3. Everything is on device and
nothing is fetched: the profiles ship in the app, the grower's own notes live in
the SwiftData store, and the grower's results stay in the store with them.

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
  average and a sentence comparing the two. A `+` adds a breeder the bundle does
  not carry, and either screen can add the grower's own notes to a breeder.
- **Your own notes, stored beside the reference.** `Models/GrowerBreeder.swift`
  adds one `@Model` (`CultivationSchemaV5`, one lightweight stage after V4) with
  the notes, an optional https link and the timestamps for one breeder.
  `BreederLibrary.allProfiles(stored:)` attaches those notes to the bundled
  profile as separate fields (`yourNotes`, `yourNotesUpdatedOn`) and appends the
  breeders only the grower has, alphabetically after the bundled order. The
  profile screen shows *Your notes* as its own card, says the notes are the
  grower's, and never edits the bundled summary, notes or links.
- **One record per breeder.** `GrowerBreederService` matches by the same folded
  name key, keeps a bundled breeder's canonical name so strains and the
  reference stay matched, updates an existing record instead of inserting a
  duplicate, removes the record when the last note and link are cleared, and
  validates before writing: a required name, 80- and 4,000-character limits, and
  https only (an address typed without a scheme is read as https). The editor
  keeps a saved name fixed — it is what the strains point at — and a new breeder
  needs a note or a link before it can be saved.
- **Lineage per cultivar.** `CultivarLineage` attaches parent lines to one
  cultivar and breeder pair rather than to a breeder. Only the bundled templates
  with an existing claim appear: Blue Dream (documented), Jack Herer (disputed)
  and White Widow (documented). A header card, the profile screen and the strain
  detail repeat that lineages are disputed.
- **Claimed figures labelled.** The strain detail now says *Claimed* beside the
  flowering window and *Breeder's claim* in the timing card, and the editor's
  breeder row offers both bundled and grower-added breeders.
- **In the data controls.** The new model is in `DataInventory`, the export's
  `breeders` section, the backup manifest check, restore and delete-all, with
  the coverage tests comparing the same lists.

## Data

| Type | What it holds |
| --- | --- |
| `BreederProfile` | name, summary, notes, links, source, review date, and the grower's notes beside them |
| `BreederLink` | title and an https URL |
| `CultivarLineage` | cultivar, breeder, parent lines, claimed yield, lineage status, source |
| `BreederCultivarSummary` | claimed weeks, the grower's observed days and finished cycle count, and the comparison sentence |
| `GrowerBreeder` | the stored model: name, notes, optional https website, created and updated dates |

The review date for the bundled reference is 15 May 2025, the same date the
bundled rule pack was verified. There is no signed or remote content pack: the
bundled profiles are code, and the grower's own notes are the only stored part.

## Decisions

- **Value types for the reference, one model for the grower's part.** Roadmap
  section 2.3 says breeder data is read-only reference content bundled now,
  updated through the signed content pipeline planned for the rules. The
  reference therefore stays a value type, while the part the grower writes —
  their own notes and link — is the additive `GrowerBreeder` entity in schema
  V5. Keeping them apart is what lets the app say which sentence is the claim
  and which is the grower's.
- **The bundled copy is never edited.** A bundled breeder keeps its canonical
  name and reference copy; the grower's notes sit in their own fields and their
  own card. Clearing the notes and link removes the stored record and leaves the
  reference exactly as it shipped.
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

`Grow CompanionTests/GrowerBreederTests.swift` covers the draft and its limits,
https normalisation, the merge with the bundled reference (attaching by key,
keeping the bundled copy, one entry per breeder, newest of two records, the
website link without repeating a bundled one), searching the grower's own notes,
one stored record per breeder, the canonical bundled name, the empty save that
removes the record, invalid saves changing nothing, the schema and migration
coverage, the export and backup round trip, and delete-all.

## Remaining work

- A signed content pack replacing the bundled profiles is out of the product:
  the app makes no network request, so reference content ships with the app and
  arrives with an app update.
- The catalogue is eleven breeders, matching the bundled templates. A grower's
  own breeder is added in the library and stays local; it has no bundled
  summary, which is why it is labelled *Added by you* and shows only the notes
  the grower wrote.
- A translator review and a device pass at the largest Dynamic Type size remain
  worth doing for the new copy, as for the rest of the Spanish draft.
