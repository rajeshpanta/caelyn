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

## Natural Cycles — not implemented

**How she gets it:** the account page offers a download; it arrives as a zip of
CSVs, of which `Daily Entries.csv` holds the per-day data.

**Why there is no adapter:** the filename is documented, the **column names are
not**. Writing a parser against guessed headers is precisely the failure mode this
document exists to prevent — a temperature column read as the wrong field is
invisible corruption. `Daily Entries.csv` goes through the generic table reader,
which matches `date`, `temperature`/`bbt` and flow-ish columns by name and reports
whatever it could not place.

**To finish it:** obtain one real export, record the exact headers here, then add
the adapter. The interface is ready; nothing else is blocking it.

---

## Ovia — not implemented

No export format verified. Generic table reader, same as above.

---

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
