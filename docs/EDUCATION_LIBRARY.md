# Education library

Roadmap section 2.8. A bundled, offline library of lessons with a checklist, an
apply-to-my-grow destination and local reading progress. It is guidance, not a
product recommendation, a diagnosis or legal advice.

## What ships

- **Content.** `Services/EducationLibrary.swift` holds four topics —
  fundamentals, pest checks, drying and curing, compliance — and six lessons
  across them. Each lesson has a stable id, a title, a summary, a four-item
  checklist, an apply destination (room, plant or compliance) and a review date.
- **Review date.** Every lesson shows the date its copy was reviewed. The date
  is the bundled rule pack's verified date (`RulePack.verifiedDate`), so the
  content review and the rule review stay on one schedule, and it is rendered
  through `Format.shortDate`, so it follows the interface language.
- **The rule pack the legal lesson was written against.** The compliance lesson
  carries `rulePackCitation`, built from `RulePack.version` and
  `RulePack.verifiedOn`, and shows it in an amber card above the checklist. The
  other lessons carry none, which a test enforces.
- **Copy limits.** A test fails if any lesson mentions a named product, a
  potency or a cannabinoid figure, or a purchase. IPM lessons describe
  observation and record keeping rather than a treatment to buy.
- **Reading progress.** `Services/EducationProgress.swift` is a value,
  `EducationReadingProgress`, with a loader and two writers. The read lesson ids
  live in `SettingsKey.educationCompletedLessons` (the key the first version of
  the screen already used, so existing progress survives) and the date each was
  marked read in `SettingsKey.educationLessonReadAt`. Both keys are in
  `SettingsKey.all`, so delete-all clears them with the other preferences.
- **Marking and un-marking.** A lesson can be marked read and marked unread
  again; un-marking removes both the id and its date, so no stale date is left
  in the preferences.
- **Summaries.** The screen shows the read count for the whole library, a
  progress ring, and a read count per topic. Each row shows the date it was read
  when it has one, and its VoiceOver value says `Read on <date>` or
  `Not read yet`.
- **Localization.** The lesson titles, summaries and checklist items go through
  `String(localized:)` with the rest of the interface, and the new copy is in the
  Spanish catalog. Legal and rule copy stays English by design; the lesson
  quotes the rule pack rather than translating it.

## Data

Nothing is stored in SwiftData: the library is bundled code, and the only
stored state is two preferences.

| Preference | Holds |
| --- | --- |
| `education.completedLessonIDs` | the ids of the lessons marked read, sorted |
| `education.lessonReadAt` | the time each read lesson was marked read, keyed by id |

Delete-all clears both. Export and backup do not carry them, as with the other
preferences: they are app state, not grow records.

## Decisions

- **The review date is the rule pack's date.** A lesson reviewed before the
  rules it describes would be misleading, so the two dates are the same one and
  the review cadence is the rule-pack cadence.
- **Only the legal lesson cites a pack.** The other topics are cultivation
  practice, not rule content, so naming a pack on them would imply an authority
  they do not have.
- **Progress is a value plus a store, not a view detail.** The first version
  read and wrote `UserDefaults` from the view. The logic now lives in a value
  with a loader and writers, so it is tested without a view and the view only
  reads it.
- **Reading is reversible.** A grower who opened a lesson by mistake, or who
  wants to re-read it later, can mark it unread; the date goes with it.
- **Apply opens one record.** The destination is the first room, the first
  plant, or the compliance screen, and a lesson whose destination does not exist
  yet says what to create instead of opening an empty screen.

## Tests

`Grow CompanionTests/EducationLibraryTests.swift` covers:

- a lesson in every topic, unique ids and a lookup by id;
- a title, summary, checklist of at least three items and a review date on every
  lesson, with the date not in the future;
- an apply destination of each kind;
- the rule pack citation on the compliance lesson only, naming the pack version
  and verified date;
- the copy limits above;
- the review date matching the rule pack;
- the progress store's empty default, a mark that records the id and the date,
  an un-mark that clears both, the per-topic count, the all-read rule, and the
  two delete-all keys.

The app and test targets compile. This environment has no simulator, so the
suite is compiled but not executed here; CI runs it on an iPhone 17 simulator
when a build or pull request reaches `main` (while the account's billing lock is
lifted).

## Remaining work

- The library has contextual entry points from Settings only. "Learn why" links
  from rule and care cards are still not built.
- A translator review and a device pass at the largest Dynamic Type size remain
  worth doing for the lesson copy, as for the rest of the Spanish draft.
- The review cadence is a build-time date. There is no remote content pack: a
  lesson update arrives with an app update, because the app makes no network
  request.
