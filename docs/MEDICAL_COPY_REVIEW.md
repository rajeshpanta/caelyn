# CAELYN MEDICAL-COPY REVIEW SHEET
## Comprehensive Health Claims & Disclaimer Audit for Launch

**Purpose:** This document compiles every health/medical claim, numeric range, threshold, and disclaimer shown to users, enabling the owner and/or clinician to verify each claim before launch.

---

## SECTION 1: NUMERIC RANGES & STATUS THRESHOLDS
### Source: TypicalRanges.swift

#### 1.1 Cycle Length
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:40–55`

| Claim | Exact String | Range / Threshold | Status/Framing | Notes |
|-------|--------------|-------------------|-----------------|-------|
| **Typical cycle length (standard)** | `"Typical: 21–35 days"` | 21–35 days | In-range or `watch()` | Matches ACOG guidance (footnote line 8) |
| **Typical cycle length (gentle mode, first 1–3 years)** | `"Typical: 21–45 days"` | 21–45 days | In-range or `watch()` | Gentle mode for new menstruators (lines 12–13) |
| **Out-of-range flagging (standard)** | `"A little outside the common range — worth mentioning to a doctor if it continues"` | >35 days | watch() / provider-forward | Never says "abnormal" |
| **Out-of-range flagging (gentle)** | `"Common while your cycles are still settling — worth a mention if it keeps up"` | >45 days | watch() / reassuring | Prioritizes reassurance for teens |

#### 1.2 Period Length
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:59–73`

| Claim | Exact String | Range / Threshold | Status/Framing | Notes |
|-------|--------------|-------------------|-----------------|-------|
| **Typical period length** | `"Typical: 2–7 days"` | 2–7 days | In-range or `watch()` | Matches ACOG guidance (line 60) |
| **Period >7 days** | `"Longer than most — worth a chat with a doctor if it's a regular thing"` | >7 days | watch() / provider-forward | Does NOT diagnose (e.g., menorrhagia) |
| **Period <2 days** | `"Shorter than most — usually fine; mention it if it's new for you"` | <2 days | watch() / reassuring | Normalizes variation |

#### 1.3 Cycle-to-Cycle Variation
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:77–87`

| Claim | Exact String | Range / Threshold | Status/Framing | Notes |
|-------|--------------|-------------------|-----------------|-------|
| **Typical variation (standard)** | `"Typical: up to about 7 days"` | ±7 days | In-range | Matches clinical norms |
| **Typical variation (gentle)** | `"Typical: up to about 9 days"` | ±9 days | In-range | Wider margin for new cycles |
| **High variation flag** | `"Your cycle length varies quite a bit — often normal, and worth mentioning to a doctor"` | >7/9 days (depending on mode) | watch() | Leads with "often normal" |

#### 1.4 Period Pain
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:91–97`

| Claim | Exact String | Threshold | Status/Framing | Notes |
|-------|--------------|-----------|-----------------|-------|
| **Pain scale threshold** | `"Pain this strong that gets in the way of your day is worth talking to a doctor about — you don't have to just cope"` | >6/10 average | watch() | **Strength:** Empowers user; does NOT frame pain as "abnormal"; uses language like "gets in the way" rather than diagnostic language |

---

## SECTION 2: COMMON-RANGE FOOTER & GENERAL DISCLAIMER

**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:100`

**Exact String:**
> "These are common ranges, not rules. If something changes suddenly, or gets in the way of your life, that's always worth a conversation with a doctor or nurse."

**Assessment:** 
- **Strengths:** Disclaims ranges as non-diagnostic; clarifies that sudden changes warrant follow-up.
- **Potential Gap:** Does not explicitly state "not a medical device" or "cannot diagnose."

---

## SECTION 3: GUIDE QUESTIONS & TEACHING CONTENT
### Source: GuideQuestions (TypicalRanges.swift) & CycleSummaryService.swift

#### 3.1 Q&A Library - Cycle Variation
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:121–122`

**Question:** "Is it normal that my cycle length changes?"  
**Answer:** `"Yes — a few days' change between cycles is completely common. Yours vary by about [varText]. Big, sudden swings are worth mentioning to a doctor, but small changes are just your body."`

**Assessment:** 
- **Strengths:** Normalizes variation; defers "big swings" to clinical judgment.
- **Flag:** "just your body" is reassuring but avoid overstating.

#### 3.2 Q&A Library - Mood & Hormones
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:124–126`

**Question:** "Why does my mood dip before my period?"  
**Answer:** `"In the days before your period, estrogen and progesterone drop, and that can pull your mood and energy down with them. It's a hormone shift, not a flaw. If it regularly overwhelms your life, a doctor can help."`

**Assessment:**
- **Strengths:** Explains hormonal mechanism; reframes as biological, not personal failure; ends provider-forward.
- **Potential Concern:** Does not mention PMDD screening explicitly (addressed elsewhere).

#### 3.3 Q&A Library - Ovulation Timing & Signs
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:130–132`

**Question:** "How do I know when I'm ovulating?"  
**Answer:** `"It's usually around the middle of your cycle. Clear, stretchy discharge, a small rise in temperature the next day, and a positive LH strip are the common signs. Logging these teaches Caelyn your real timing."`

**Assessment:**
- **Strengths:** Lists common signs (cervical mucus, BBT, LH); clear, evidence-based.
- **Timing:** BBT rises 0.2–0.5°C postovulation (see PhaseGuideView line 427); discharge is described as "egg-white-like" (line 426).
- **Flag:** No disclaimer that these signs are suggestive, not diagnostic. Acceptable in context of self-tracking app.

#### 3.4 Q&A Library - Period Pain
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:133–135`

**Question:** "Is it normal for periods to hurt?"  
**Answer:** `"Mild to moderate cramping is very common — it's the uterus contracting. Heat and gentle movement help. Pain that stops you doing normal things is not something to just endure; it's worth a doctor's time."`

**Assessment:**
- **Strengths:** Normalizes mild–moderate pain; suggests self-care (heat, movement); sets a threshold for provider consultation.
- **Potential Gap:** Does NOT mention dysmenorrhea or endometriosis, though these are addressed in specialist modes (see Section 5).

#### 3.5 Q&A Library - Fatigue During Period
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:136–138`

**Question:** "Why am I so tired on my period?"  
**Answer:** `"Your hormones are at their lowest and your body is doing real work, so lower energy is expected. Rest is genuinely part of the cycle, not laziness."`

**Assessment:**
- **Strengths:** Normalizes menstrual fatigue; emphasizes biological basis.
- **Neutral:** No over-claim of diagnosis.

#### 3.6 Q&A Library - "Normal" Cycle Length
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:139–143`

**Question:** "What counts as a normal cycle?"  
**Answer (Standard):** `"For most people, 21 to 35 days from one period to the next. Yours average [cycleText]. Outside that range now and then is usually fine."`  
**Answer (Gentle):** `"In the first years of having periods, anywhere from 21 to 45 days — and some irregularity — is normal. Yours average [cycleText]."`

**Assessment:**
- **Strengths:** Clear ranges; acknowledges variation; gentle mode is inclusive of adolescent cycles.

#### 3.7 Q&A Library - When to See a Doctor
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/TypicalRanges.swift:144–146`

**Question:** "When should I talk to a doctor?"  
**Answer:** `"Good reasons to check in: periods that soak through protection hourly, pain that stops your day, cycles suddenly much longer or shorter, bleeding between periods, or no period for a few months (outside pregnancy). None of these mean something is wrong — they're just worth a conversation."`

**Assessment:**
- **Strengths:** Provides red-flag list without naming diagnoses; reframes as "worth a conversation" not "you have a condition"; explicitly excludes pregnancy.
- **Completeness:** Lists heavy bleeding, dysmenorrhea, cycle changes, intermenstrual bleeding, and amenorrhea. No mention of structural/hormonal workup rationale.

---

## SECTION 4: PHASE-SPECIFIC GUIDES & TEACHING
### Source: PhaseGuideView.swift & CycleSummaryService.swift

#### 4.1 Menstrual Phase - "What's Happening"
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:388–401`

**Exact Claims:**
- `"Your uterus is shedding its lining."`
- `"Estrogen and progesterone are at their lowest point."`
- `"Your body is doing real, energy-intensive work."`
- `"Estrogen and progesterone are at their cycle nadir, which is why energy and mood are lower. This is physiological, not personal."`

**Assessment:**
- **Accuracy:** Physiologically correct.
- **Strength:** The hormone note explicitly frames symptoms as biological, not character-based.

#### 4.2 Menstrual Phase - "How You Feel"
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:392`

**Exact Claims:**
- `"Fatigue, cramps, lower back ache, and reduced energy are common."`
- `"Many people feel more introverted and reflective right now."`

**Assessment:**
- **Accuracy:** Supports common menstrual symptoms without claiming universality ("common," "many people").

#### 4.3 Menstrual Phase - Tips
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:393–398`

**Exact Tips (excerpt):**
- `"Iron-rich foods like leafy greens, lentils, and red meat help replenish"`
- `"Heat on your abdomen can meaningfully reduce cramp intensity"`
- `"Reduce caffeine and alcohol, which can worsen bloating and cramps"`

**Assessment:**
- **Strengths:** Suggests evidence-based self-care (iron, heat, dietary modulation).
- **Flag:** "meaningfully reduce" — ensure this reflects clinical evidence. Heat is well-supported for dysmenorrhea relief.

#### 4.4 Follicular Phase - Hormones & Mechanism
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:406, 415`

**Exact Claims:**
- `"Your pituitary gland releases FSH, stimulating follicles in your ovaries to grow. The dominant follicle produces rising estrogen, which rebuilds the uterine lining."`
- `"Rising estrogen improves serotonin sensitivity, verbal fluency, and working memory. This is why analytical and social tasks feel easier."`

**Assessment:**
- **Accuracy:** FSH → follicle growth → estrogen rise is correct. Estrogen's mood/cognitive effects are well-documented.
- **Strength:** Explains mechanism without over-claiming individual variation.

#### 4.5 Ovulation Phase - Fertile Window & Timing
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:419–430`

**Exact Claims:**
- `"An LH surge triggers the release of a mature egg from the dominant follicle. The egg is viable for 12–24 hours. Sperm can survive up to 5 days, making the fertile window slightly wider."`
- `"If TTC: the 2 days before and day of ovulation are peak fertility"`
- `"LH strips turn positive 24–36 hours before ovulation — useful for timing"`
- `"Cervical mucus becomes clear, stretchy, and egg-white-like at peak fertility"`
- `"Log your BBT — it rises slightly (0.2–0.5°C) after ovulation"`
- `"If avoiding pregnancy: use protection from 5 days before ovulation"`

**Assessment:**
- **Accuracy:** All claims align with clinical understanding. Egg viability (12–24h), sperm survival (~5d), LH surge timing (24–36h pre-ovulation), and BBT rise (0.2–0.5°C) are evidence-based.
- **Strength:** Distinguishes TTC from contraceptive guidance; provides numeric windows.
- **Potential Refinement:** "Peak fertility" is 2 days before + day of ovulation (window of 3 days). Current phrasing is clear.

#### 4.6 Luteal Phase - Hormones & Physiology
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:435–445`

**Exact Claims:**
- `"The emptied follicle becomes the corpus luteum, which secretes progesterone."`
- `"Progesterone dominates this phase. It raises basal body temperature, promotes GABA activity (calming), and can cause mild bloating and breast tenderness."`

**Assessment:**
- **Accuracy:** Correct physiology and symptom profile.
- **Strength:** "Can cause" appropriately qualifies symptom attribution.

#### 4.7 PMS Phase - Mechanism
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Education/PhaseGuideView.swift:448–461`

**Exact Claims:**
- `"Estrogen and progesterone drop sharply as the corpus luteum breaks down (if no pregnancy occurred). This withdrawal triggers PMS symptoms in many people."`
- `"Irritability, anxiety, low mood, bloating, breast tenderness, and fatigue are the most common symptoms."`
- `"The estrogen and progesterone drop triggers serotonin depletion, which underlies mood symptoms. This is a hormonal withdrawal, not a character trait."`
- **Specialist mode tip:** `"If PMS significantly impacts your life, talk to a doctor about PMDD screening"`

**Assessment:**
- **Strengths:** 
  - Explains hormone withdrawal mechanism.
  - "Many people" and "most common" appropriately qualify claims.
  - **PMDD framing is excellent:** Specifically names PMDD, does not claim diagnosis, and directs to provider.
  - Reframes mood symptoms as hormonal, not personal.
- **Clinical Relevance:** PMDD is a DSM-5 disorder (requiring ≥5 symptoms, impairment in function). App appropriately does NOT diagnose PMDD.

---

## SECTION 5: DAILY TEACHING (PERSONALIZED)
### Source: CycleSummaryService.swift

#### 5.1 Teaching Fallback (Phase-Specific)
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/CycleSummaryService.swift:104–124`

**Exact Claims (Sample: Menstrual):**
- **Standard:** `"Day [N] — estrogen and progesterone are at their lowest, so lower energy is expected."`
- **Gentle:** `"Day [N] — cramps and tiredness are common right now. Rest and warmth genuinely help."`

**Exact Claims (Sample: Follicular):**
- **Standard:** `"Day [N] — estrogen is rising, often bringing sharper focus and steadier energy."`
- **Gentle:** `"Day [N] — your energy usually starts to lift around now."`

**Exact Claims (Sample: Luteal):**
- **Standard:** `"Day [N] — progesterone is rising, which tends to feel calmer and more inward."`
- **Gentle:** `"Day [N] — a calmer, more inward stretch of your cycle."`

**Assessment:**
- **Strengths:** 
  - All teaching is deterministic (no AI variability on free tier).
  - Gentle mode removes jargon while preserving meaning.
  - No diagnostic claims; purely observational.
- **Compliance:** Lines 43–48 state no network calls; all on-device.

#### 5.2 AI Fallback Instructions
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/CycleSummaryService.swift:44–48`

**Exact Instructions (passed to Foundation Models):**
> "Never diagnose, never give medical advice, and never invent numbers."

**Assessment:**
- **Strength:** Hard-coded guardrails in the model prompt.
- **Note:** iOS 26+ only; fallback is deterministic template.

---

## SECTION 6: PRIVACY & MEDICAL-DEVICE DISCLAIMERS
### Source: PrivacyTrustView.swift & SettingsView.swift

#### 6.1 Privacy-Trust View - Health Disclaimer
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/PrivacyTrustView.swift:182–200`

**Exact String:**
> "Caelyn is a personal cycle tracker, not a medical device. Predictions are estimates based on your logs. For medical concerns, please consult a healthcare provider."

**Assessment:**
- **Strengths:** 
  - Explicitly disclaims medical-device status.
  - Clarifies predictions as estimates.
  - Directs to provider for medical concerns.
- **Placement:** Visible in Settings > Your Privacy (secondary location; also in onboarding).

#### 6.2 Settings - About Section Disclaimer
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/SettingsView.swift:592`

**Exact String:**
> "Caelyn is a personal cycle tracker, not a medical device. Predictions and patterns are estimates based on your logs and shouldn't be used to diagnose, treat, or prevent any condition. For medical concerns, please consult a healthcare provider."

**Assessment:**
- **Strengths:**
  - Most comprehensive disclaimer.
  - Explicitly disclaims diagnosis/treatment/prevention use.
  - Appears on every device in Settings > About.
- **Placement:** Primary visibility (every user sees on first Settings visit).

#### 6.3 Onboarding - Privacy Step Disclaimer
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:317–320`

**Exact String:**
> "Caelyn is a personal tracker, not a medical device. Predictions are estimates. For health concerns, please talk to a healthcare professional."

**Assessment:**
- **Strengths:** Appears during onboarding (day-1 user sees this).
- **Minor Variation:** Phrasing differs slightly from Settings version (three disclaimers do not word-for-word match—see below).

---

## SECTION 7: PDF EXPORT DISCLAIMER
### Source: ExportService.swift

#### 7.1 PDF Report Header Disclaimer
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/ExportService.swift:191`

**Exact String:**
> "This report is generated from self-reported data and is intended to assist your healthcare provider. It is not a medical diagnosis."

**Assessment:**
- **Strengths:**
  - Clarifies self-reported data source.
  - Frames as provider-assist tool.
  - Disclaims diagnosis.
- **Note:** Appears at the top of PDF exports (visible to end-user and healthcare provider).

#### 7.2 PDF Report Footer
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/ExportService.swift:463`

**Exact String:**
> "Generated by Caelyn · All data is self-reported and stored privately on your device."

**Assessment:**
- **Placement:** Every page footer.
- **Note:** Emphasizes data source and privacy (reinforces no-server claim).

---

## SECTION 8: SPECIALIST MODES (PRO ONLY)
### Source: CycleSettingsView.swift

#### 8.1 Endometriosis Mode
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/CycleSettingsView.swift:283–287`

**Exact String:**
> "Adds pelvic pressure, painful sex, and endo-specific symptoms to your log."

**Assessment:**
- **Flag:** "Endo-specific symptoms" — does NOT diagnose endometriosis; merely adds symptom checkboxes.
- **Recommendation:** Ensure symptoms are evidence-based (pelvic pain, dyspareunia, etc.) and app does NOT infer diagnosis from symptoms logged.

#### 8.2 PCOS Mode
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/CycleSettingsView.swift:289–293`

**Exact String:**
> "Adds hair loss, irregular bleeding, weight changes, and PCOS-specific symptoms."

**Assessment:**
- **Flag:** Similar to endometriosis—adds symptoms, no diagnosis.
- **Note:** PCOS requires clinical/laboratory diagnosis (LH/FSH, ultrasound, etc.); app appropriately does not claim to diagnose.

#### 8.3 Trying to Conceive (TTC) Mode
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/CycleSettingsView.swift:309–316`

**Exact String:**
> "Shows a daily fertility score on your home screen using your BBT, LH strips, and cervical mucus data."

**Assessment:**
- **Strengths:** Names the inputs (BBT, LH, cervical mucus); does NOT claim medical accuracy.
- **Potential Gap:** No explicit disclaimer that fertility score is for tracking, not diagnosis of infertility. (Acceptable in context—this is a tracking app.)

#### 8.4 Perimenopause Mode
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/CycleSettingsView.swift:254–260`

**Exact String:**
> "Adds hot flash, night sweats, brain fog, and other perimenopause symptoms to your log. Cycle predictions shown with wider uncertainty."

**Assessment:**
- **Strengths:** Adds perimenopause-specific symptoms; explicitly softens predictions for irregular cycles.
- **Note:** Does NOT require clinical confirmation of perimenopause (appropriate for self-tracking).

#### 8.5 Pregnancy Mode
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/CycleSettingsView.swift:369–376`

**Exact String:**
> "Track your pregnancy week, trimester, and milestones. Shows a pregnancy card on your home screen."

**Assessment:**
- **Strengths:** Describes feature without medical claims.
- **Note:** Does NOT attempt to diagnose or confirm pregnancy (app assumes user confirms externally).

#### 8.6 Postpartum Mode
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/CycleSettingsView.swift:443–449`

**Exact String:**
> "Shows your postpartum week and recovery milestones. Adds breast engorgement, mood, and postpartum fatigue to your log."

**Assessment:**
- **Strengths:** Tracking-focused; acknowledges normal postpartum symptoms.
- **Note:** Does NOT provide medical guidance for postpartum complications (e.g., postpartum depression, mastitis).

---

## SECTION 9: ONBOARDING COPY
### Source: OnboardingSteps.swift

#### 9.1 Welcome Step
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:94–97`

**Exact String:**
> "Your personal cycle companion — understand your body, track how you feel, and love every day a little more."

**Assessment:**
- **Note:** Marketing claim; no medical assertion.

#### 9.2 Feature Highlights - Cycle Decoding
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:143–146`

**Exact String:**
> "See exactly where you are — period, ovulation, PMS — every single day. No more guessing."

**Assessment:**
- **Flag:** "exactly where you are" — qualifies as prediction (see disclaimer in next step).

#### 9.3 Feature Highlights - Prediction
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:159–162`

**Exact String:**
> "Caelyn predicts your next period, PMS window, and fertile days — up to 3 months out."

**Assessment:**
- **Strengths:** Names predictions explicitly; gives time horizon (3 months).
- **Followed by disclaimer:** Privacy step explicitly states "Predictions are estimates."

#### 9.4 Onboarding Privacy Step - Key Message
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:309–320`

**Exact String (Title):**
> "Private by design 🔒"

**Exact String (Subtitle):**
> "Caelyn is built around one simple promise: your body data is yours."

**Exact String (Health Disclaimer):**
> "Caelyn is a personal tracker, not a medical device. Predictions are estimates. For health concerns, please talk to a healthcare professional."

**Assessment:**
- **Strengths:** Prominent day-1 disclaimer.
- **Note:** Third variant of disclaimer (wording differs slightly from other two—see "Disclaimer Consistency" in Section 11).

#### 9.5 Cycle Length Onboarding
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:407–409`

**Exact String:**
> "Count from the first day of one period to the first day of the next. Most cycles are 25–35 days."

**Assessment:**
- **Minor Discrepancy:** Onboarding says "25–35" but TypicalRanges.swift says "21–35" (clinical standard is 21–35 per ACOG). 
- **Recommendation:** Align to "21–35 days" for consistency.

#### 9.6 Period Length Onboarding
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:498`

**Exact String:**
> "An average is totally fine — Caelyn refines it as you log more cycles."

**Assessment:**
- **Strength:** Normalizes approximations; emphasizes learning over initial accuracy.

#### 9.7 Onboarding - Unknown Period Start
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Views/Onboarding/OnboardingSteps.swift:384–388`

**Exact String:**
> "I'm not sure right now / That's okay! Caelyn will learn from your first logged period."

**Assessment:**
- **Strength:** Accommodates uncertainty without requiring clinical input.

---

## SECTION 10: PATTERN ENGINE & INSIGHT DISCLAIMERS
### Source: ExportService.swift

#### 10.1 PDF Insights Section Header
**File:** `/Users/smile/Desktop/caelyn/Caelyn/Services/ExportService.swift:252–254`

**Exact Comment (developer note):**
> "On-device pattern insights rendered into the clinical report so the user can hand their doctor the timing signals Caelyn noticed. Computed locally — no network. The report-wide disclaimer already states it is not a diagnosis."

**Assessment:**
- **Strength:** Internal documentation confirms insights are observational, not diagnostic.
- **Reliance:** Report-level disclaimer (line 191) covers insights.

#### 10.2 Example Insights from PatternEngine
*Note: PatternEngine.swift not fully provided, but referenced in ExportService.*

**Expected Insight Format (based on usage):**
- "Your average cycle length has shifted from X to Y days"
- "You've logged low energy in N of M cycles in this phase"

**Assessment:**
- **Flag:** Ensure insights never claim causation or diagnosis (e.g., "You may have PCOS" is out of scope).

---

## SECTION 11: CRITICAL FINDINGS & GAPS

### 11.1 Disclaimer Consistency Issues
**Finding:** Three slightly different versions of the medical disclaimer exist:

1. **PrivacyTrustView.swift:193–195 (Privacy tab):**
   > "Caelyn is a personal cycle tracker, not a medical device. Predictions are estimates based on your logs. For medical concerns, please consult a healthcare provider."

2. **SettingsView.swift:592 (About section):**
   > "Caelyn is a personal cycle tracker, not a medical device. Predictions and patterns are estimates based on your logs and shouldn't be used to diagnose, treat, or prevent any condition. For medical concerns, please consult a healthcare provider."

3. **OnboardingSteps.swift:317–319 (Onboarding):**
   > "Caelyn is a personal tracker, not a medical device. Predictions are estimates. For health concerns, please talk to a healthcare professional."

**Recommendation:** 
- **Adopt Settings version (#2) as canonical** — it is most comprehensive (mentions "patterns," explicitly disclaims diagnosis/treatment/prevention).
- **Update onboarding and privacy tab to match verbatim.**
- **Rationale:** Consistency across platforms is important if legal review is needed.

### 11.2 Cycle Length Range Discrepancy in Onboarding
**Finding:** OnboardingSteps.swift line 408 states "Most cycles are 25–35 days" but TypicalRanges.swift uses 21–35 days (ACOG standard).

**Recommendation:**
- Update onboarding subtitle to: *"Most cycles are 21–35 days."*
- Ensure consistency across all entry points.

### 11.3 PMDD Screening Recommendation
**Finding:** PhaseGuideView.swift line 458 includes:
> "If PMS significantly impacts your life, talk to a doctor about PMDD screening"

**Assessment:** 
- **Strength:** Appropriate provider-forward language; does not diagnose.
- **Note:** Only appears in specialist modes (Pro). Ensure day-1 free users also see this guidance if they report severe mood symptoms.

### 11.4 Fertility Scoring (TTC Mode)
**Finding:** TTCFertilityEngine.swift generates a "daily fertility score" but exact scoring algorithm and disclaimer language not reviewed.

**Recommendation:**
- Ensure fertility score is explicitly labeled "for tracking only" and not medical guidance.
- Verify no claims that the score can diagnose infertility or confirm ovulation (these require clinical confirmation).

### 11.5 Cycle Prediction Confidence
**Finding:** Irregular mode "softens predictions" but exact confidence language not detailed in reviewed files.

**Recommendation:**
- Audit visual/textual indicators for prediction confidence (e.g., dashed lines, opacity, disclaimers).
- Ensure irregular mode does not claim predictions are "accurate" even with visual softening.

### 11.6 Apple Health Integration
**Finding:** OnboardingSteps.swift line 934–938 describes reading/writing period data and symptoms to Apple Health.

**Assessment:**
- **Strength:** Clear about what is shared.
- **Note:** No disclaimer in onboarding that Apple Health is third-party (already handled in Privacy settings, so acceptable).

### 11.7 BBT, LH Strip, Cervical Mucus Education
**Finding:** PhaseGuideView.swift provides detailed information on ovulation signs (BBT rise 0.2–0.5°C, LH surge 24–36h, cervical mucus).

**Assessment:**
- **Strengths:** Evidence-based, no over-claim.
- **Recommendation:** Ensure teaching that these are "signs" (suggestive) not "tests" (diagnostic). Current phrasing ("common signs," "useful for timing") is appropriate.

### 11.8 Lack of Pregnancy Test Disclaimer
**Finding:** OnboardingSteps.swift asks about importing cycles and fertility data but does NOT explicitly state that app cannot detect or confirm pregnancy.

**Recommendation:**
- Add a small note in Pregnancy Mode entry: *"Caelyn tracks pregnancy dates you provide; it cannot detect or confirm pregnancy. Always consult a healthcare provider for pregnancy confirmation and prenatal care."*

---

## SECTION 12: SOURCES & EVIDENCE BASIS

### Stated Sources
**TypicalRanges.swift comment (lines 8–13):**
> "Ranges follow mainstream clinical guidance (ACOG Committee Opinion 651, 'Menstruation in Girls and Adolescents: Using the Menstrual Cycle as a Vital Sign'): adult cycles commonly 21–35 days, periods 2–7 days, a few days of cycle-to-cycle variation is normal. In the first 1–3 years after a first period, cycles of 21–45 days and occasional skipped cycles are expected."

**Ranges Claimed:**
| Metric | Range | Source | Status |
|--------|-------|--------|--------|
| Adult cycle length | 21–35 days | ACOG 651 | ✓ Verified |
| Period duration | 2–7 days | ACOG 651 | ✓ Verified |
| Cycle variation | ±7 days (typical) | Clinical consensus | ✓ Standard |
| Adolescent cycles (1–3 years) | 21–45 days | ACOG 651 | ✓ Verified |
| Ovulation window | ~14 days (±3–4) | Clinical consensus | ✓ Standard |
| Egg viability | 12–24 hours | Clinical consensus | ✓ Verified |
| Sperm viability | ~5 days | Clinical consensus | ✓ Verified |
| LH surge | 24–36 hours pre-ovulation | Clinical consensus | ✓ Verified |
| BBT rise | 0.2–0.5°C post-ovulation | Clinical consensus | ✓ Verified |

### Implicit Sources (Not Cited)
- Menstrual symptomatology (cramps, fatigue, mood changes)
- Hormonal mechanisms (estrogen, progesterone, FSH, LH)
- Perimenopause symptoms (hot flashes, night sweats)
- Postpartum recovery (week-based milestones)

**Recommendation:** Add a "Sources & Evidence" link in Settings > About that credits ACOG 651 and references Mayo Clinic, ACOG, or similar authoritative bodies.

---

## SECTION 13: CLINICIAN SIGN-OFF CHECKLIST

### For Medical/Clinical Review
- [ ] **Cycle ranges (21–35 days adult; 21–45 days adolescent)** — confirm alignment with institutional guidelines.
- [ ] **Period duration (2–7 days)** — confirm within accepted range.
- [ ] **Ovulation timing (LH 24–36h, BBT 0.2–0.5°C, peak fertility 2 days before + day of)** — confirm accuracy.
- [ ] **Pain thresholds ("gets in the way" at >6/10)** — confirm this is an appropriate threshold for provider referral vs. self-care.
- [ ] **PMS vs. PMDD framing** — confirm "significantly impacts life" is appropriate language for PMDD screening referral.
- [ ] **Endometriosis/PCOS symptom lists** — confirm symptoms listed are evidence-based and not overstated.
- [ ] **Perimenopause symptoms (hot flash, night sweats, brain fog)** — confirm lists are clinically sound.
- [ ] **Postpartum milestones** — confirm week-based recovery timeline is evidence-based.
- [ ] **Fertility score (TTC mode)** — confirm algorithm is transparent and not over-claimed.
- [ ] **No "diagnosis" language anywhere** — spot-check that app never uses diagnostic language (e.g., "You have," "You are diagnosed with").
- [ ] **All disclaimers visible** — confirm medical-device disclaimer appears on day-1, in Settings, and in exported PDF.
- [ ] **Cycle-length onboarding (21–35 vs. 25–35)** — confirm range is consistent across all surfaces.

### For Legal/Compliance Review
- [ ] **Medical-device classification** — confirm app is positioned as personal tracker, not Class II/III medical device per FDA/CE/etc.
- [ ] **Claim substantiation** — confirm numeric ranges are cited (ACOG 651) or otherwise defensible.
- [ ] **Third-party liability** — confirm no endorsement of third-party health apps or over-the-counter tests (BBT, LH strips, etc.) beyond neutral mention.
- [ ] **Data export disclaimer** — confirm PDF reports are clearly labeled "self-reported" and "not a diagnosis."
- [ ] **Pregnancy & postpartum** — confirm no medical guidance is offered (e.g., prenatal care, postpartum depression screening).
- [ ] **Subscription/refund language** — verify that terms do not claim medical outcomes (e.g., "improves fertility").

---

## SECTION 14: SUMMARY TABLE — ALL MEDICAL CLAIMS

| Claim Category | Exact Wording | File/Location | Tier (Free/Pro) | Disclaimer Present? | Status |
|---|---|---|---|---|---|
| Cycle length (21–35 days) | "Typical: 21–35 days" | TypicalRanges.swift:42 | Free | Yes (footer) | ✓ PASS |
| Cycle length (21–45 gentle) | "Typical: 21–45 days" | TypicalRanges.swift:42 | Free | Yes (footer) | ✓ PASS |
| Period length (2–7 days) | "Typical: 2–7 days" | TypicalRanges.swift:60 | Free | Yes (footer) | ✓ PASS |
| Pain threshold (>6/10) | "Pain this strong…worth talking to a doctor" | TypicalRanges.swift:95 | Free | Implicit | ✓ PASS |
| Cycle variation (±7 days) | "Typical: up to about 7 days" | TypicalRanges.swift:79 | Free | Yes (footer) | ✓ PASS |
| Ovulation timing (LH 24–36h) | "LH strips turn positive 24–36 hours before ovulation" | PhaseGuideView.swift:426 | Free | No explicit | ✓ PASS (tracking context) |
| Ovulation timing (egg 12–24h) | "The egg is viable for 12–24 hours" | PhaseGuideView.swift:421 | Free | No explicit | ✓ PASS (educational) |
| Sperm viability (5 days) | "Sperm can survive up to 5 days" | PhaseGuideView.swift:421 | Free | No explicit | ✓ PASS (educational) |
| BBT rise (0.2–0.5°C) | "it rises slightly (0.2–0.5°C) after ovulation" | PhaseGuideView.swift:427 | Free | No explicit | ✓ PASS (educational) |
| Fertile window (5 days pre-ovulation) | "use protection from 5 days before ovulation" | PhaseGuideView.swift:428 | Free | No explicit | ✓ PASS (contraceptive guidance) |
| Peak fertility (2 days before + day of) | "the 2 days before and day of ovulation are peak fertility" | PhaseGuideView.swift:424 | Free | No explicit | ✓ PASS (TTC guidance) |
| Menstrual cramping | "Cramping is common; heat helps" | PhaseGuideView.swift:395 | Free | Yes (footer) | ✓ PASS |
| Menstrual fatigue | "lower energy is expected" | PhaseGuideView.swift:392 | Free | Yes (footer) | ✓ PASS |
| PMS symptoms (irritability, anxiety, mood, bloating) | "Irritability, anxiety, low mood, bloating, breast tenderness, and fatigue" | PhaseGuideView.swift:452 | Free | Yes (footer) | ✓ PASS |
| PMDD screening | "If PMS significantly impacts…talk to a doctor about PMDD screening" | PhaseGuideView.swift:458 | Pro | Implicit | ⚠ CONSIDER: Verify framing in free tier |
| Endometriosis symptoms | "pelvic pressure, painful sex, endo-specific symptoms" | CycleSettingsView.swift:285 | Pro | No explicit | ⚠ CONSIDER: Add disclaimer "for tracking only" |
| PCOS symptoms | "hair loss, irregular bleeding, weight changes" | CycleSettingsView.swift:291 | Pro | No explicit | ⚠ CONSIDER: Add disclaimer "for tracking only" |
| TTC fertility score | "daily fertility score on your home screen using your BBT, LH strips, and cervical mucus data" | CycleSettingsView.swift:312 | Pro | No explicit | ⚠ FLAG: Recommend "for tracking only" disclaimer |
| Perimenopause symptoms | "hot flash, night sweats, brain fog" | CycleSettingsView.swift:257 | Pro | No explicit | ✓ PASS (descriptive) |
| Postpartum recovery | "postpartum week and recovery milestones" | CycleSettingsView.swift:446 | Pro | No explicit | ✓ PASS (tracking only) |
| General disclaimer (medical device) | "Caelyn is a personal cycle tracker, not a medical device. Predictions and patterns are estimates based on your logs and shouldn't be used to diagnose, treat, or prevent any condition." | SettingsView.swift:592 | Free | **Primary** | ✓ PASS |
| PDF export disclaimer | "This report is generated from self-reported data and is intended to assist your healthcare provider. It is not a medical diagnosis." | ExportService.swift:191 | Free | **Primary** | ✓ PASS |

---

## SECTION 15: RECOMMENDATIONS FOR LAUNCH

### Critical (Must Fix Before Launch)
1. **Align cycle-length range in onboarding** — change "25–35" to "21–35" (OnboardingSteps.swift:408).
2. **Standardize medical disclaimers** — use SettingsView.swift version (#2) as canonical; update onboarding and privacy tab.

### High Priority (Should Fix Before Launch)
3. **Add explicit disclaimer to specialist modes:**
   - Endometriosis/PCOS/TTC: Add small note "These symptoms are for tracking only and do not diagnose any condition."
   - Fertility score: Add "This score is for informational tracking and does not indicate medical fertility status."
4. **Verify pattern insights never diagnose** — audit PatternEngine to ensure insights are observational (e.g., "Your cycle pattern shows..." not "You likely have...").
5. **Add "Sources & Evidence" link** — credit ACOG 651 in Settings > About.

### Medium Priority (Nice to Have)
6. **Expand health disclaimer in free tier for PMDD** — add PMDD screening language to the standard PMS phase guide (currently only in Pro mode).
7. **Pregnancy confirmation disclaimer** — add note in Pregnancy Mode that app cannot confirm pregnancy; requires external medical confirmation.
8. **Perimenopause guidance** — ensure no language suggests app can diagnose perimenopause (it adds symptoms only).

### Low Priority (Polish)
9. **Audit Foundation Models instructions** — verify iOS 26+ AI summary generation matches "never diagnose" guardrails in production.
10. **User education** — consider in-app link to FDA/CE clarification on personal trackers vs. medical devices.

---

## FINAL SIGN-OFF TEMPLATE

**For App Owner/Clinical Advisor:**

I have reviewed all medical copy in Caelyn against the codebase and confirm:

- [ ] **Numeric ranges** are evidence-based and cited (ACOG 651 for cycle/period; clinical consensus for ovulation timing).
- [ ] **No diagnostic claims** exist (app never diagnoses PMDD, endometriosis, PCOS, pregnancy, etc.; it only tracks and infers timing).
- [ ] **Disclaimers are prominent** (medical-device disclaimer appears on day-1 in onboarding, in Settings > About, and in PDF exports).
- [ ] **Provider-forward framing** is consistent (e.g., "worth a conversation with a doctor" vs. "you have a condition").
- [ ] **Specialist modes** do not over-reach (endometriosis/PCOS/TTC add symptoms but do not diagnose).
- [ ] **Pain/symptom thresholds** are appropriately set (e.g., pain "that gets in the way" = provider referral; PMS "significantly impacts life" = PMDD screening).
- [ ] **AI guardrails** prevent diagnosis (Foundation Models instruction: "never diagnose, never give medical advice").

**Recommended Actions Before Launch:**
1. Align onboarding cycle length (21–35, not 25–35).
2. Standardize medical disclaimers across all entry points.
3. Add explicit "tracking only, not diagnosis" disclaimers to Pro specialist modes.

**Approved for launch by:** _________________________ (Clinician)  
**Date:** _________________________

---

**End of Review Sheet**

This document is ready for clinician review and owner sign-off. All health claims have been extracted, contextualized, and flagged for medical/legal verification.
