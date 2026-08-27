# Bringing history in from other apps

What Caelyn can read, how each format was verified, and what it deliberately does
not claim. Written so the next person to touch the importers can tell evidence
from assumption.

**The standing rule:** a source is listed in `ImportSourceID` only when its
structure has been verified against real exports. Everything else goes through the
generic readers, which map less but cannot mis-map. Supporting three apps
accurately beats claiming ten.

---

## Verification status at a glance

| Source | Structure verified | Confidence | Adapter |
|---|---|---|---|
| Caelyn export | Yes — written by `ExportService` in this repo | Total | `CaelynExportSource` |
| Clue | Yes — two independent open-source parsers of real exports | High for structure, partial for the option vocabulary | `ClueSource` |
| Flo | Yes — two independent open-source parsers, for `operationalData.cycles` only | High for cycles, nothing else verified | `FloSource` |
| Natural Cycles | **No** — file name known, column names not | — | Generic table reader |
| Ovia | **No** | — | Generic table reader |
| Anything else | n/a | — | Generic table / JSON reader |

"Two independent parsers" means two separately-written community projects that
parse real exported files and agree on the structure. That is weaker than vendor
documentation and stronger than reading a marketing page. Where it is all we have,
the adapter is written to fail closed: every mapping is keyed on an exact name, so
an unknown value is reported as unmapped rather than assigned to a neighbour.

---

## Caelyn's own export

**How she gets it:** Settings → Export data → CSV.

**Format:** the CSV `ExportService.generateCSV` writes. Columns: `date`, `flow`,
`pain`, `pain_types`, `symptoms`, `mood`, `energy_level`, `medication`,
`basal_temperature`, `cervical_mucus`, `sexual_activity`, `ovulation_test`,
`pregnancy_test`, `custom_symptoms`, `note`.

**Mapped:** all of them. This round trip is tested field by field.

**Backward compatibility:** only `date` is required. An export from any earlier
version imports; it simply carries fewer columns. A column added in a *future*
version is reported as unmapped rather than dropped silently, so an older build
reading a newer file says so.

**Detection:** `date` plus all three of `flow`, `symptoms`, `pain_types`. That
combination is not one another tracker picks by chance. The filename is never
evidence.

---

## Clue

**How she gets it:** Clue → menu in Cycle View → Settings → *Request data*. Clue
emails a download link that expires after 72 hours, and shows a password on screen.
The download is a zip containing `measurements.json`. **iOS Files can unzip it in
place** (long-press → Uncompress); she then picks the JSON. Caelyn does not read
zips — see Limitations.

**Format:** a flat JSON array of

```json
{ "date": "2026-01-05T00:00:00.000Z", "type": "period", "value": { "option": "heavy" } }
```

`value` is either a single `{"option": …}` or an array of them. `bbt` is the
exception and carries `{"temperature": <number>}`.

**Mapped**

| Clue type | Options read | Lands in |
|---|---|---|
| `period` | light, medium, heavy, very_heavy | `flow` |
| `spotting` | any | `Symptom.irregularBleed` — **never** `flow` |
| `pain` | period_cramps, lower_back, breast_tenderness, headache, migraine, migraine_with_aura, ovulation | `symptoms` + `painTypes` |
| `feelings` | happy, sad, angry, anxious, indifferent, mood_swings, sensitive | `mood` |
| `energy` | fully_energized, energetic, tired, exhausted | `energyLevel` |
| `discharge` | none, sticky, creamy, watery, egg_white | `cervicalMucus` |
| `digestion` | nauseated, nauseous, bloated, gassy | `symptoms` |
| `sex_life` | protected_sex, unprotected_sex, withdrawal | `sexualActivity` |
| `bbt` | `value.temperature` | `basalTemperature` |

**Not mapped** (reported, never guessed): cravings, skin, hair, sleep, exercise,
collection method, medication, tests, appointments, ailments, and sex-drive
options — Caelyn has no field for them.

**Limitations**
- Clue's export contains **no cycle start markers**. Caelyn does not need them; it
  reconstructs cycles from bleeding days, exactly as it does with its own data.
- The option vocabulary above is the verified subset, not a guarantee of
  completeness. An option Clue adds later is reported as unmapped.
- Zip files are not read. She unzips in Files first.

---

## Flo

**How she gets it:** Flo has no in-app download. Flo → avatar → Help → *Contact
us* → ask for a data export. Flo emails a TXT (human-readable) and a JSON
(machine-readable). Caelyn reads the JSON. In Anonymous mode the account has to be
registered first.

**Format:** a JSON object whose `operationalData.cycles` is an array of
`{"period_start_date": …, "period_end_date": …}`.

**Mapped:** the bleeding days of every cycle.

**Not mapped:** everything else in the file, counted and reported by top-level key.

**Limitations — the important ones**
- The verified structure carries **period date ranges only**: no per-day intensity,
  no symptoms, no temperatures. Whether other sections exist in a shape that could
  be parsed is *unverified*, and unverified is not implemented.
- Because `FlowLevel` has no "unspecified", imported days are recorded as
  **medium**, and the preview says so in as many words before she confirms. This is
  the one place Caelyn writes a value the source did not state, and it is disclosed
  rather than hidden.
- A "period" longer than 15 days is rejected as a data error rather than written
  out as weeks of bleeding, which would wreck every cycle average.

---

## Period Tracker by GP Apps — Apple Health bridge, no file adapter

**The app:** the big magenta flower with a yellow centre. *Period Tracker by GP
Apps*, **GP International LLC**, `com.gpapps.ptrackerlite`, **v12.1.1** (10 Jul
2026), App Store ID **330376830**. Verified via the iTunes lookup API, 2026-08-26.

**Not the lookalike.** ABISHKKING / Simple Design ship "Period Tracker Period
Calendar" (`com.abishkking.periodcalendar` on iOS, `com.popularapp.periodcalendar`
on Play) — a pink *diary* with a small white flower. Different company, different
app, different data. The picker subtitle names GP Apps so nobody follows the wrong
instructions, and a test enforces it.

**What GP Apps actually offers** — from its own listing and support pages:

| Path | Status |
|---|---|
| HealthKit | **Yes** — "Now supports HealthKit". This is the route. |
| Online backup account | Yes, cross-platform (iOS / Android / Windows) — but server-side; the user never receives a file |
| **Emailed backup file** | **Yes** — and this is the interesting one |
| Email export of period dates and notes | Yes — "for doctor's visits", i.e. human-readable |

**The emailed backup is real, and its format is undocumented.** GP Apps' FAQ tells
users to *"open your most recently emailed backup… then click on the attachment"*,
and elsewhere refers to *"your backup file"* and to emailing it to support. So
unlike most trackers, a genuine portable artifact exists and reaches the user.

But nothing describes what is inside it. No published schema, no open-source
parser, no reverse-engineered example — GitHub code search for the bundle id
returns only app-inventory lists. Building a parser from that would mean guessing
at the structure of years of reproductive history, which is the one thing this
codebase does not do.

**This is the closest any unsupported source has come to a real adapter.** One real
backup file would settle it: examine the attachment, confirm the structure, and
build a first-class adapter to the same standard as Clue and Flo. Until then the
route is Apple Health, which is stated on the current listing and which Caelyn
already reads sixteen types out of.

**Recoverable via the bridge:** whatever GP Apps writes into Health, out of
menstrual flow, spotting, basal body temperature, cervical mucus, ovulation tests,
pregnancy tests, sexual activity, and the symptom and pain categories.
**Not recoverable:** written notes, moods, weight — Apple Health has no type Caelyn
reads for them.

**Wiring:** `ImportSourceGuide.periodTracker` keeps the app's own name on the row
while carrying `source: .appleHealth` and `route: .appleHealthAfterInstructions`.
Instructions come first because the sync switch lives inside GP Apps' app. No new
HealthKit permission was added.

**Source filtering.** Apple Health is a shared pool — Flo, Clue, Caelyn itself and
the Health app all write into it — so a route promising *Period Tracker* history has
to mean that and nothing else. `HealthSyncService.SourceFilter.periodTrackerGPApps`
narrows the read to `com.gpapps.ptrackerlite` and `com.gpapps.ptracker`, matching on
`ImportObservation.sourceBundleID`, which HealthKit stamps from
`sourceRevision.source` and no caller can forge. The plain **Apple Health** row
passes no filter and still imports everything she has approved.

Two consequences worth remembering. A filtered route **never advances the sync
anchors** — it examined one app's slice, and moving the shared anchor would tell the
next full sync that everything else had already been seen. And it **ignores
deletions**, because a deleted record is identified by id alone and a record from
another app is not this route's to clear.

Imports from this route are recorded as **"Period Tracker via Apple Health"** rather
than plain Apple Health, so her list of imports says which app each batch came from
and undo stays per-app.

## Natural Cycles — Apple Health bridge, no file adapter

**The app:** *Natural Cycles: Fertility App*, **NaturalCycles Nordic AB**,
`com.naturalcycles.cordova`, **v5.8.4**, App Store ID **765535549**. Verified via
the iTunes lookup API, 2026-08-26.

**A real export exists and is still not parsed.** Natural Cycles does provide a
data download — a compressed folder of CSVs, one of which holds daily entries with
temperatures and period entries. Unlike GP Apps or Simple Design, the artifact is
unambiguous. What is missing is any description of its **columns**: their help
centre sits behind a Cloudflare challenge, no independent parser exists on GitHub,
and no third party documents the schema. Reading a temperature column by position
and guessing its meaning is exactly the failure mode this file exists to prevent.

**The Health route is documented by the vendor.** Natural Cycles' own support
material describes Settings → Integrations → Apple Health, where a user chooses to
export and/or import cycle data.

**One real limitation, and it matters more here than anywhere else.** Natural
Cycles documents that **temperatures cannot be exported to Apple Health** — a
platform restriction on writing Apple's temperature fields — *except* for users of
their own connected thermometer. Temperature is the entire premise of Natural
Cycles, so the picker note says this before she starts rather than letting her
discover an empty chart afterwards.

**Recoverable via the bridge:** period days and cycle history, plus any other type
Natural Cycles writes among the sixteen Caelyn reads.
**Not recoverable:** temperatures for most users, and anything Apple Health has no
type Caelyn reads for.

**Wiring:** `ImportSourceGuide.naturalCycles`, filtered to
`com.naturalcycles.cordova`, provenance **"Natural Cycles via Apple Health"**.

**To upgrade to a direct adapter,** one real export folder settles it — the daily
entries CSV with its header row is all the evidence needed.

## Glow — Apple Health bridge, no file adapter

**The app:** *Glow Ovulation & Period App*, **Glow, Inc.**, `com.upwlabs.emma`,
**v12.0.3**, App Store ID **638021335**. Verified via the iTunes lookup API,
2026-08-26. **Not** *Glow Eve Period Tracker* (`com.glowing.lexie`, ID 1002275138)
— same company, same version number, different app and a different HealthKit
source. The filter covers only the main app; folding Eve in would import its
records under Glow's name.

**The CSV export exists and is documented in one sentence.** Glow's current support
site, in full: *"Can I download my data? Please reach out to support@glowing.com and
our team can send you a CSV file of your data."* (published 2025-11-28). Human-
fulfilled, no self-serve, and nothing describes the file — no name, no delimiter,
no headers, no schema. GitHub has no Glow parser. **LOW confidence — no adapter.**

**The Health route is the best-documented of any bridge here.** Glow's support site,
verbatim: *"go to your More page > click 'Connect with health apps' > turn on Health
app. Go to your Settings in App click the red 'All Categories on' link and click the
'Allow' button on the upper left. You should be able to see a plethora of
Reproductive Health options as well as Sleep, Weight and Exercise."*

That gives the exact menu wording, and it names reproductive health categories
rather than a vague "supports HealthKit". It also documents **the step people miss**:
turning the Health app on inside Glow is not sufficient, because iOS keeps every
category switched off until *All Categories on* is tapped. A migration that skipped
that would find nothing and look broken.

**Stated honestly:** what is verified is that Glow's Health connection *covers*
reproductive health categories and that its listing says *"Sync data between Glow
and Apple Health app."* Which types it **writes**, as opposed to requests, is not
documented and is only observable on a device.

**Recoverable via the bridge:** whatever Glow writes among the sixteen types Caelyn
reads — Glow tracks flow, symptoms, basal body temperature, cervical mucus and
sexual activity, all of which Health can carry.
**Not recoverable:** notes, moods, weight, and Glow's community content.

**Wiring:** `ImportSourceGuide.glow`, filtered to `com.upwlabs.emma`, provenance
**"Glow via Apple Health"**.

## Ovia — researched in depth, deliberately **not** offered

**The app:** *Ovia Cycle & Pregnancy Tracker*, **Ovuline, Inc.**, `com.ovuline`,
**v8.9.0**, App Store ID **570244389**. The name confirms the formerly separate
Ovia Pregnancy app is now folded into the main app; *Ovia Parenting & Baby Tracker*
(`com.ovuline.Parenting`) remains separate.

Ovia is the **best-documented export of any source examined** and is still not
implemented. Both available routes fail, for different reasons, and the second
failure is the interesting one.

### The direct export — real, well documented, columns unknown

Ovia's help centre, verbatim: *"Go to the 'More' menu in the bottom bar → Settings
→ Export my data. This will send a .zip file to the email associated with your
account that includes several .csv files of your logged data."* The export arrives
**within 48 hours** and **expires after 7 days**. It contains everything ever
entered or viewed — symptoms, cycle, ovulation — plus uploaded photos and videos.

There is also a trap worth recording: Ovia organises tracking into **goals** (cycle,
pregnancy, postpartum, peri/menopause), and its guide states that viewing or
exporting data from a *previous* goal requires switching back to that goal first.
A user now in Pregnancy who exports without switching gets an export missing her
cycle history — and nothing warns her.

What is missing is the same thing missing everywhere: **the column headers.** No
schema is published, and GitHub code search for Ovia or Ovuline export parsing
returns nothing. So no adapter.

### The Apple Health route — available, and actively misleading

This is why Ovia gets no row at all, unlike Period Tracker and Natural Cycles.

Ovia's current App Store description says *"Share data from Ovia to the Apple Health
app"*, so it does write. But **no source anywhere says it writes menstrual flow.**
Ovia's own guide describes the integration in the *pull* direction — *"Ovia is able
to pull sleep, steps, and weight metrics"* — and the only independent analysis of
what it pushes lists blood pressure, weight, steps and body temperature, noting that
of fertility metrics it sends **only basal body temperature**.

Caelyn reads sixteen types. Against that list, an Ovia-filtered Health import would
most likely surface **a few temperatures and no period days at all**.

That is not a corruption risk — the merge rules hold regardless — but it is worse
than offering nothing. A row saying "Ovia" that returns a preview reading *"3
temperature readings"* invites the conclusion that her history has moved when none
of it has. Silently omitting the data that matters, while appearing to succeed, is
the failure this whole pipeline is built to prevent.

So Ovia is left out until there is evidence for a route that carries period days.

### What would change this

**One real export.** The zip's CSV filenames and one header row would be enough to
build a Flo/Clue-quality adapter — and the direct export is where Ovia's history
actually lives, so that is the route worth having. Failing that, a single screenshot
of Health → Cycle Tracking → Data Sources & Access on a phone with Ovia installed
would settle the Health question either way.

## The generic readers

**Table (CSV).** Finds a date column by name, or failing that by finding a column
whose values parse as dates. Matches other columns against the alias table in
`GenericTableSource.aliases`, exact names first and substring matches second, so
`Period Intensity` and `Basal temperature (C)` resolve. Every unclaimed column is
reported.

**JSON.** Looks for an array of per-day objects, either at the top level or under
one of `days`, `entries`, `logs`, `records`, `data`, `items`, `history`. Maps keys
through the same alias table.

Neither ever reports itself as certain, so a specific adapter always gets first
refusal on a file.

---

## Things worth knowing before changing any of this

**Spotting is not flow.** `PredictionEngine.cycles(from:)` treats any non-nil
`flow` as a bleeding day and starts a new cycle after a gap of more than one day.
Writing spotting into `flow` invents period starts and distorts every cycle length
she has. Spotting from every source becomes `Symptom.irregularBleed`. There are
tests for this in both suites; do not "simplify" them away.

**`DateFormatter` lies.** It reads `2026-02-30` as March 1st, `05.01.2026` with a
slash format, and `Jan 5, 2026` with `MM/dd/yyyy` — all without complaint. Every
date Caelyn accepts is round-tripped back through the same format and must come out
identical. `ImportValues.strictDate` is the only correct way to parse a date here.

**Ambiguous columns are decided once, for the whole column.** `03/04/2026` is
either March or April, and choosing per row would read half a year one way and half
the other. A format has to account for at least 60% of the column; below that
Caelyn refuses the file rather than reading most of it wrong.

**Temperature units are inferred from the number.** Human basal temperature
occupies two non-overlapping bands, roughly 30–45 °C and 86–113 °F, so a
Fahrenheit column converts and anything in neither band is refused.

**Nothing leaves the device.** Files are read with `Data(contentsOf:)` and parsed
in-process. No network call, no third-party parser, no upload — and the pipeline
must stay that way.
