<!-- Generated 2026-06-29 from a 12-area parallel scan of the current code (278 features). -->

# Caelyn — Feature & Function Inventory (current)

## A. What works today

### Home tab
1. Time-based greeting header with cycle day and current phase
2. Privacy chip badge in header
3. Large 240px cycle ring showing day progress with period/ovulation/PMS color coding
4. Tappable phase badge that opens the phase guide
5. Dynamic phase headline plus compassionate one-liner hint
6. Predicted period window (start–end) with ±N-day variation margin
7. Low-confidence hint prompting users to log more cycles
8. Phase color legend (period/ovulation/PMS)
9. Quick Actions bar (Log Period, Symptoms, Mood, Note) and Daily Log sheet
10. Logging streak card with 14-day dot grid and milestone icons
11. Active-period prompt banner with one-tap logging
12. Late-period prompt banner with contextual messaging
13. Period start-date editor chip (change/remove) during active window
14. Auto-detecting irregular-mode banner (enable or dismiss) and persistent irregular badge
15. Mood check-in card (8 moods) with context-aware confirmation
16. "Coming Up" predictive timeline (PMS, period, fertile window) with empty state
17. Pattern Insight card surfacing the top symptom for the current phase
18. Phase-tinted background gradient and full accessibility annotations
19. Soft paywall (ProUpsellCard) shown once on first real prediction (Pro)
20. TTC fertility dashboard: 0–100 score, signals, fertile countdown (Pro)
21. Pregnancy mode card: weeks/trimester, milestones, due date (Pro)
22. Postpartum mode card: weeks postpartum, milestones, 26-week cutoff prompt (Pro)

### Calendar tab
23. Month navigation (buttons, swipe, jump-to-today) with animated transitions
24. 42-day grid showing logged/predicted/PMS/ovulation phases
25. Tap-any-day detail sheet to log flow, symptoms, mood, notes, ovulation tests
26. Active period window with 1-day gap tolerance and "fill me in" prompts
27. Predicted period, adaptive PMS, and fertile/ovulation windows
28. Adaptive PMS window learned from symptoms (after 3+ cycles)
29. Learned luteal length from LH tests (after 3+ cycles; 14-day default)
30. Note indicators, today ring, relative-date and "Future" labels
31. First-day-of-week setting (Sun/Mon/Sat), legend, and accessibility labels
32. Month summary card: period range, days logged, top 3 symptoms

### Log / Daily log form
33. 14-day horizontal date selector with entry indicators and "Today" jump
34. Cycle-day indicator for the selected date
35. Flow selector (None/Spotting/Light/Medium/Heavy) with phantom-entry guard
36. Pain 0–10 slider with verbal labels plus multi-select pain locations
37. Symptoms: 11 base + condition-specific sets + up to 5 custom, each with Mild/Mod/Severe severity
38. Mood (11), energy (5 grades), and basal temperature input (validated 35–42°C)
39. Ovulation test selector (negative/rising/surge/positive) with contextual hints
40. Free-form notes and medication free-text, both auto-save on unfocus
41. Advanced section: pregnancy-test toggle, sexual-activity toggle, cervical-mucus dropdown
42. Entry deletion with confirmation (syncs deletion to HealthKit)
43. Fire-and-forget HealthKit sync after mutations; throttled review prompts

### Insights tab & charts
44. Stats grid (avg cycle/period, variation, logged days)
45. Patterns section (early symptom, period pain, cycle variation)
46. Dismissible, lag-aware insights feed (free shows 2, Pro shows all)
47. Cycle history timeline (length, period length, top symptom, avg pain)
48. Confidence scoring (3-dot visual) and persisted insight dismissal
49. Empty state with animated progress to 3 cycles
50. Cycle-length line chart, period-length bar chart (Pro)
51. Symptom-frequency and mood-pattern bar charts (Pro)
52. Pain trend (area+line) and BBT chart with 36.4°C threshold (Pro)

### Intelligence engines
53. Cycle reconstruction from flow logs with gap detection
54. Recency-weighted cycle-length averaging (0.85 decay) and variation detection
55. Next-period prediction, ovulation estimation, 5-day fertile window
56. Cycle-phase classification with short-cycle validity checks
57. Irregular-cycle detection (5 types) and period-late detection
58. Prediction confidence tiers (low/medium/high) with explanations
59. Learned luteal length (≥3 cycles, clamped 9–17 days) (Pro)
60. Adaptive PMS-onset learning (≥3 cycles) (Pro)
61. PatternEngine 9-detector suite: phase-symptom correlation, pre-period mood dip, energy curve, cycle-length trend, PMS predictor, symptom lead-time, pain trend, frequent symptom, condition insights
62. Condition-mode insights for perimenopause/PCOS/endometriosis (observational, non-diagnostic)
63. TTC fertility engine: cycle-position, LH, cervical-mucus, and BBT-shift scoring with labels (Pro)
64. Time-series providers for cycle/period length, BBT, pain, symptom/mood/energy distributions

### Cycle & condition modes
65. Cycle/period length and last-period-start configuration
66. Irregular cycle mode (free)
67. Perimenopause, endometriosis, PCOS condition modes adding symptom sets (Pro)
68. TTC, Pregnancy (with due date), Postpartum (with birth date) modes (Pro)
69. Birth control mode: pill/patch/ring method, start dates, and reminders

### Reminders & notifications
70. Period-start reminder (0–3 day offset), ovulation reminder, daily check-in (silent)
71. Medication reminder (time-sensitive, breaks Focus); BC pill/patch/ring cycle-aware reminders
72. Quiet hours (defers 22:00–07:00) and private-notification neutral phrasing
73. Notification permission management, tap routing with highlight, legacy cleanup

### Privacy, security & lock
74. App lock via Face ID/Touch ID/passcode with auto-lock on background and 30s timeout
75. App-preview masking in the task switcher with privacy-shield overlay
76. Privacy manifest (NSPrivacyTracking=false, UserDefaults-only) and health disclaimer
77. Privacy promise cards and subpoena-resistant messaging

### Data, persistence & export
78. Local-only SwiftData storage (CloudKit `.none`); CycleEntry and UserProfile models
79. Three-tier store-failure fallback (disk → preserved-corrupt+fresh → in-memory) with banner
80. Corrupted-store preservation with sidecars and store-mode diagnostics
81. CSV export (RFC 4180, configurable range) (free)
82. PDF clinical report with summary, insights, timeline, chart, table (Pro)
83. Two-step "delete all data" wipe with notification cancellation

### HealthKit
84. Authorization request and availability check (device + Info.plist strings)
85. Menstrual flow, symptom, and pain export to Apple Health
86. Menstrual flow import from Apple Health (create/update entries)
87. Per-entry sync with serialized per-day queuing; delete-then-rewrite dedup

### Widgets, Watch & sync bridge
88. Small home widget: cycle day, phase badge, days-until-period (free)
89. Medium and Large home widgets with events timeline; Standby support (Pro)
90. Accessory circular and rectangular lock-screen widgets, hide-preview aware (Pro)
91. Honest widget empty state (no fabricated numbers) and midnight-recompute timeline
92. Watch home view (ring, phase, stat pills, event line, log button) and empty state
93. Watch quick log (flow, 5 moods, pain) with sync confirmation
94. WidgetDataStore (App Group), WidgetCycleMath (parity-tested), snapshot builder, continuous sync modifier
95. WatchBridgeService and WatchDataModel two-way sync (Pro-gated push to watch)

### Onboarding
96. Welcome, feature carousel, and privacy-promises screens
97. Last-period picker (with "unsure" skip), cycle-length and period-length pickers with defaults
98. Tracking-goals multi-select and reminder-preference toggles (requests permission)
99. Optional Apple Health sync (auto-skips on iPad) and biometric/passcode setup
100. Completion celebration, progress indicator with back nav, UserProfile persistence

### Monetization
101. Three tiers (Monthly $3.99 / Yearly $19.99 / Lifetime $49.99) with selector
102. 1-week free trial on Yearly (eligibility-checked) (Pro)
103. StoreKit 2 purchase flow, JWS verification, transaction finish, restore purchases
104. Pending-purchase handling and offline entitlement cache (prevents false downgrade)
105. Feature comparison table, per-month/savings badges, loading/error states, already-Pro CTA

### Education & app shell
106. Multi-tab navigation with iPad split-view and theme preference (light/dark/system)
107. Full phase guides (menstrual, follicular, ovulation, luteal, PMS, unknown) with hormone notes and tips
108. App Store review prompts (after 5 entries, capped, cooldown)

## B. Full feature & function inventory

### 1. Home tab (free unless noted)
1. Greeting header (cycle day + phase) — works
2. Privacy chip — works
3. Cycle ring visualization — works
4. Phase badge → PhaseGuideView — works
5. Phase headline & compassionate hint — works
6. Predicted period window with ±N margin — works
7. Prediction confidence hint — works
8. Phase legend — works
9. Quick Actions bar + Daily Log sheet — works
10. Logging streak card (14-day dots) — works
11. Active-period prompt — works
12. Late-period prompt — works
13. Period start-date editor chip — works
14. Irregular-mode banner + persistent badge — works
15. Mood check-in card (8 moods) — works
16. Coming Up events timeline + empty state — works
17. Pattern Insight card (single top symptom) — works
18. Phase-aware background gradient — works
19. Accessibility annotations — works
20. Soft paywall card — works (Pro upsell)
21. TTC fertility dashboard — works (Pro)
22. Pregnancy mode card — works (Pro)
23. Postpartum mode card — works (Pro)

### 2. Calendar tab (free)
24. Month navigation (buttons/swipe/today) — works
25. 42-day phase grid — works
26. Day-cell logging sheet — works
27. Active period window (1-day gap tolerance) — works
28. Predicted period/PMS/ovulation windows — works
29. Adaptive PMS window (learned) — works
30. Learned luteal length — works
31. Note indicators, today ring — works
32. Relative-date and Future labels — works
33. First-day-of-week setting — works
34. Calendar legend — works
35. Month summary card — works
36. Accessibility labels — works
37. Cycle predictions — partial (limited accuracy with <2 logged cycles)

### 3. Log / Daily log form (free)
38. 14-day date selector with indicators — works
39. Cycle-day indicator — works
40. Flow tracking (5 levels) — works
41. Pain 0–10 slider — works
42. Pain location multi-select — works
43. Symptoms (11 base + condition + 5 custom) — works
44. Per-symptom severity (Mild/Mod/Severe) — works
45. Mood (11) — works
46. Energy (5 grades) — works
47. Basal body temperature (validated) — works
48. Ovulation test results with hints — works
49. Free-form notes (auto-save) — works
50. Medication free-text (auto-save) — works
51. Pregnancy-test toggle — works
52. Sexual-activity toggle — works
53. Cervical-mucus dropdown — works
54. Entry deletion with confirmation (+HK delete) — works
55. Fire-and-forget HealthKit sync — works
56. App Store review prompts — works
57. Collapsible Advanced section — works

### 4. Insights tab & charts
58. Stats grid — works (free)
59. Patterns section — works (free)
60. Dismissible lag-aware insights feed (2 free / all Pro) — works (free)
61. Cycle history timeline — works (free)
62. Confidence scoring (3 dots) — works (free)
63. Insight dismissal persistence — works (free)
64. Empty state (progress to 3 cycles) — works (free)
65. Year-in-review calendar grid — partial (12 months Pro / 3 months free)
66. Cycle-length line chart — works (Pro)
67. Period-length bar chart — works (Pro)
68. Symptom-frequency chart — works (Pro)
69. Mood-pattern chart — works (Pro)
70. Pain trend chart — works (Pro)
71. BBT chart with threshold — works (Pro)

### 5. Intelligence engines (backend)
72. Cycle reconstruction + gap detection — works (free)
73. Recency-weighted cycle-length averaging — works (free)
74. Cycle-length variation detection — works (free)
75. Current cycle-day calculation — works (free)
76. Next-period prediction — works (free)
77. Ovulation estimation (luteal model) — works (free)
78. Fertile-window prediction (5-day) — works (free)
79. Cycle-phase classification — works (free)
80. Irregular-cycle detection (5 types) — works (free)
81. Period-late detection — works (free)
82. Prediction confidence tiers — works (free)
83. Time-series providers (cycle, period, BBT, pain) — works (free)
84. Symptom/mood/energy frequency distributions — works (free)
85. Early-period symptom + avg period pain — works (free)
86. Days-logged metrics, logging streak, daily-state tracking — works (free)
87. Learned luteal length — works (Pro)
88. Adaptive PMS window — works (Pro)
89. PatternEngine: phase-symptom correlation — works
90. PatternEngine: pre-period mood dip — works
91. PatternEngine: energy curve — works
92. PatternEngine: cycle-length trend (≥6 cycles) — works
93. PatternEngine: PMS predictor symptom — works
94. PatternEngine: symptom lead-time (lag-aware) — works
95. PatternEngine: pain trend (≥6 cycles) — works
96. PatternEngine: most-frequent symptom — works
97. Condition insights (perimenopause/PCOS/endo) — works
98. TTC daily fertility score (0–100) — works (Pro)
99. TTC signal summaries — works (Pro)
100. TTC cycle-position / LH / mucus / BBT scoring — works (Pro)

### 6. Cycle & condition modes (Settings)
101. Cycle-length config (18–45) — works (free)
102. Period-length config (1–12) — works (free)
103. Last-period start date — works (free)
104. Irregular cycle mode — works (free)
105. Perimenopause mode — works (Pro)
106. Endometriosis mode — works (Pro)
107. PCOS mode — works (Pro)
108. TTC mode — works (Pro)
109. Pregnancy mode (with due date) — works (Pro)
110. Postpartum mode (with birth date) — works (Pro)
111. Birth control tracking (pill/patch/ring) + reminders — works (free)

### 7. Reminders & notifications (free unless noted)
112. Period-start reminder (0–3 day offset) — works
113. Ovulation reminder — works
114. Daily check-in reminder (silent) — works
115. Medication reminder (time-sensitive) — works
116. BC pill/patch/ring reminders (cycle-aware) — works
117. Quiet hours enforcement — works
118. Private-notification neutral phrasing — works
119. Permission management, tap routing, legacy cleanup — works

### 8. Privacy, security & lock
120. App lock (biometric/passcode) — works
121. Lock gate at entry, auto-lock on background, foreground prompt — works
122. Dynamic lock labels by device capability — works
123. App-preview masking + privacy shield overlay — works (free)
124. Private notifications mode — works (free)
125. No-tracking declaration + privacy manifest (UserDefaults CA92.1) — works
126. Health disclaimer + subpoena-resistant messaging + privacy promise cards — works

### 9. Data, persistence & export
127. Local-only SwiftData storage (CloudKit `.none`) — works
128. CycleEntry & UserProfile models — works
129. Custom symptoms (up to 5) — works (free)
130. Store-failure 3-tier fallback + corrupted-store preservation + store-mode tracking — works
131. createdAt/updatedAt timestamps — works
132. CSV export (configurable range) — works (free)
133. PDF clinical report — works (Pro)
134. Export range selection (3mo/1yr/all) — works (free)
135. On-device backup info (honest local-only explainer) — works
136. Delete all data (two-step) — works
137. Reset onboarding (DEBUG only) — works

### 10. HealthKit
138. Authorization request + availability check — works
139. Menstrual flow export — works (free)
140. Symptom export (severity-mapped) — works (free)
141. Pain export — works (free)
142. Menstrual flow import — works (free)
143. Health flow read/write toggles — works (free)
144. Health symptoms write — works (free)
145. Health symptoms read/import — stub (toggle disabled, "coming in a future update")

### 11. Widgets, Watch & sync bridge
146. Small home widget — works (free)
147. Medium home widget — works (Pro)
148. Large home widget + Standby — works (Pro)
149. Accessory circular widget — works (Pro)
150. Accessory rectangular widget — works (Pro)
151. Widget empty state (no fabricated data) — works
152. Midnight-recompute timeline (parity-tested) — works
153. Lock-screen hide-preview masking (accessory only) — works
154. Watch home view + empty state — works
155. Watch quick log — works
156. WidgetDataStore (App Group) — works
157. WidgetCycleMath recompute engine — works
158. WidgetSnapshotBuilder — works
159. WidgetDataSyncModifier (continuous sync, Pro-gated watch push) — works
160. WatchBridgeService + WatchDataModel two-way sync — works

### 12. Onboarding (free)
161. Welcome screen — works
162. Feature highlights carousel (3 slides) — works
163. Privacy-promises grid — works
164. Last-period picker (with skip) — works
165. Cycle-length config — works
166. Period-length config — works
167. Tracking-goals multi-select — works
168. Reminder preferences (requests permission) — works
169. Apple Health sync option (iPad auto-skip) — works
170. Biometric/passcode setup — works
171. Completion celebration — works
172. Progress indicator + back nav — works
173. Uncertain-data handling (sensible defaults) — works
174. UserProfile persistence — works

### 13. Monetization
175. Three-tier pricing + selector — works
176. Free trial on Yearly — works (Pro)
177. StoreKit 2 purchase flow — works (Pro)
178. Restore purchases — works (Pro)
179. Pending-purchase handling — works (Pro)
180. Offline entitlement cache — works (Pro)
181. Feature comparison table — works
182. Pro status detection (screenshot override) — works
183. Soft paywall (ProUpsellCard) — works
184. Yearly per-month breakdown — works (Pro)
185. Savings % / Best Value badge — works (Pro)
186. Loading/error/retry states — works
187. Already-Pro CTA disable — works
188. Free-trial label generation (eligibility-gated) — works (Pro)
189. Transaction verification — works (Pro)
190. Paywall hero title & copy — works

### 14. App shell & education
191. Multi-tab navigation + notification routing — works
192. iPad split-view layout — works
193. Theme preference (light/dark/system) — works (note: Home/Calendar surfaces still hardcoded light)
194. Widget data sync on launch/resume — works
195. watchOS connectivity activation — works
196. Phase guides: menstrual, follicular, ovulation, luteal, PMS, unknown fallback — works
197. Phase-specific tips + hormone education + fertility education — works
198. Privacy policy & legal links — works

### 15. Disabled / retracted (UI present, not functional)
199. Partner Share (CloudKit) — partial/disabled placeholder (Pro); does not sync cycle data
200. iCloud / cross-device sync — retracted to honest local-only; export is the backup path
201. HealthKit symptom & pain import — stub (flow import only)

## C. What still needs to be added or upgraded

### Intelligence & predictions
1. [ADD] Anomaly/outlier detection — flag very short/long cycles, missing flow, surprise second period, skipped cycle (vs irregular auto-detect only)
2. [UPGRADE] Prediction accuracy tracking & auto-calibration — record predicted vs actual periods and recalibrate
3. [UPGRADE] Variability-aware weighting + per-user late threshold — weight recent data more for variable cycles; learn each user's true "late" point
4. [ADD] Symptom co-occurrence / syndrome clustering — surface multi-symptom clusters (e.g. bloating+cramps+headache), not just one top symptom
5. [ADD] Phase-by-phase symptom/mood/pain distribution maps — full per-phase prevalence beyond single best correlation
6. [ADD] Cycle-to-cycle comparison view — "this cycle vs last," differential, side-by-side past cycles
7. [UPGRADE] Cold-start intelligence — lower 6+-cycle detector thresholds / early "beta" insights; raise free insight cap above 2 and free year-view above 3 months
8. [ADD] Surface learned values to user — show learned luteal length and PMS-onset vs defaults with confidence
9. [UPGRADE] TTC depth — multi-day rolling fertility curve, conception-timing recommendations, per-user signal-weight learning, BBT change-point detection, cervical-mucus transition recognition
10. [ADD] HealthKit signals into intelligence — correlate sleep, HRV, workouts, steps with cycle phases
11. [ADD] Intervention & life-event correlation — log supplements/exercise/diet/stress/illness and measure effect
12. [ADD] Logging-recommendation & data-quality engine — suggest what to log today and flag gaps that hurt predictions
13. [UPGRADE] Predictive lead-time for mood/energy/pain — currently symptom-only

### Privacy, data & safety
14. [ADD] Encryption at rest — CryptoKit/Secure Enclave for the SQLite store
15. [ADD] CSV/JSON data import & restore — including bulk import from competitor apps (currently export-only / HealthKit one-way)
16. [ADD] Encrypted/password-protected exports + anonymized "for doctor" redaction mode (exports are plaintext)
17. [ADD] Data integrity verification + persistent offline-entry queue — checksums; in-memory fallback data currently lost on kill
18. [UPGRADE] Schema-migration visibility + HealthKit sync audit trail + data retention/archival policies
19. [UPGRADE] E2E encryption design for any future iCloud backup

### Platform & integrations
20. [UPGRADE] Partner Share — rebuild the disabled CloudKit share so it actually syncs cycle phase/events (Pro)
21. [ADD] Cross-device iCloud sync (E2E-encrypted) — currently local-only
22. [UPGRADE] HealthKit symptom & pain import — finish the stubbed reverse-sync; add smart retry for failed writes
23. [ADD] Wearable/fertility-device integration — Oura, Tempdrop, Apple Watch temp sensors
24. [UPGRADE] Birth control coverage — add IUD, implant, shot, mini-pill, barrier; export BC data to HealthKit
25. [UPGRADE] Notification controls — per-reminder granular toggles, snooze, OS grouping (threadIdentifier), schedule preview
26. [ADD] Widget/Watch settings — size, data shown, refresh; extend widget refresh window beyond 7 days
27. [UPGRADE] Watch reliability — quick-log failure handling, acknowledgment handshake, offline queue; replace 3650-iteration recompute loop with date math
28. [ADD] Watch/widget Pro UX — paywall/badge on watch; Pro chart mini-views on watch/widgets
29. [ADD] Provider/calendar sharing — direct healthcare-provider share and external calendar export (note: some intentionally out of scope for privacy)

### Monetization
30. [ADD] In-app subscription management — show tier, renewal date, history; cross-tier upgrade/downgrade flow
31. [ADD] Free trial on Monthly tier (currently Yearly-only)
32. [UPGRADE] Enable Family Sharing (all products currently non-shareable)
33. [ADD] Promo/offer codes + win-back/cancellation messaging
34. [ADD] Monetization analytics — paywall impressions, conversion, failure reasons
35. [UPGRADE] Server-side receipt validation (currently client-only)
36. [ADD] In-app support/refund entry point

### Views & logging
37. [ADD] Week view and year view (month-only today)
38. [ADD] Calendar search/filter by symptom/flow/mood/phase
39. [ADD] Cycle statistics & confidence on calendar — variance, average, irregularity; prediction-confidence overlay on grid
40. [UPGRADE] Surface LH/ovulation confirmation on calendar; deep-link Coming Up events
41. [ADD] Bulk/multi-day logging + symptom templates
42. [ADD] Logging fields — weight, dedicated sleep quantity/quality, photo attachments (test strips), time-of-day precision
43. [UPGRADE] Medication structure — dosage/frequency/timing + autocomplete (free-text only today)
44. [ADD] Flow semantics — "period start" vs "irregular spotting" tag and flow-duration tracking
45. [UPGRADE] In-form fertile-window/ovulation prediction; dedicated pregnancy-mode fields (weight gain, trimester symptoms)

### Polish, UX & education
46. [UPGRADE] Adaptive dark mode for hardcoded-light Home/Calendar surfaces (theme setting exists but these ignore it)
47. [ADD] Phase-guide inline health disclaimer + localization (i18n); deep links into guides from Home/Insights/Calendar
48. [UPGRADE] Onboarding depth — contextual tooltips, notification-timing config, smart goal defaults, expanded feature highlights
49. [ADD] Post-onboarding edit/revisit flow; first-time guided lock-setup; privacy-toggle explainers
50. [UPGRADE] Biometric error context + auth-state VoiceOver hints
51. [UPGRADE] iPad/landscape layout for charts, timeline, and year view
52. [ADD] Chart captions/legends ("what this means") + insight grouping/filtering UI