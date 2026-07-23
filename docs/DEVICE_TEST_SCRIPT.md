# Caelyn — On-Device Pre-Submission QA Checklist

A tap-by-tap checklist for testing Caelyn on real devices before App Store submission. This document verifies features that the simulator cannot test. Work through each section methodically; checkbox each step after confirming the expected result.

---

## A. ONBOARDING + FIRST PREDICTION

**Note:** Use a fresh simulator or test device reset to onboarding if testing all steps below. Pre-existing data can shortcut some flows.

### A1. Welcome & Carousel

- [ ] **App launches to Welcome screen** — logo and text fade in smoothly, floating icons animate.
  - **Expected:** Tap "Let's begin ✨" → advances to Feature Highlights carousel.

- [ ] **Feature carousel (3 pages)** — swipe left or use next/back buttons to navigate all three slides.
  - **Expected:** Page 1 (cycle decoded), Page 2 (private intelligence), Page 3 (for your body). Each page's copy and icon load cleanly.

- [ ] **Privacy promises grid** — tap Privacy-Promises screen.
  - **Expected:** Shows 5–6 cards (no servers, no tracking, no account, on-device, data export, HealthKit optional). Each tap expands/collapses detail.

### A2. Cycle & Period Config

- [ ] **Last period picker** — select a date from 30–90 days ago (or "I'm not sure" to skip).
  - **Expected:** Date picker works smoothly. Selected date appears in summary. "Unsure" skips to sensible defaults (28-day cycle, 5-day period).

- [ ] **Cycle length picker** — spin to select 18–45 days (default 28).
  - **Expected:** Picker bounds are enforced. Tapping ± buttons increments by 1.

- [ ] **Period length picker** — spin to select 1–12 days (default 5).
  - **Expected:** Works similarly to cycle length. Confirmation text updates.

### A3. Tracking Goals & Notifications

- [ ] **Tracking goals multi-select** — check boxes for any combination (e.g., period, fertility, mood, health).
  - **Expected:** Selection persists to summary. At least one goal can be checked.

- [ ] **Reminder preferences** — toggle "daily check-in", "period start", "ovulation" (not all necessarily available on first screen).
  - **Expected:** Tapping any toggle that is OFF shows the iOS permission prompt (first time only). After granting, toggle moves to ON. Device Settings → Notifications confirm Caelyn appears in notified apps.

- [ ] **Permission requests are **not** mandatory** — dismiss any prompt without granting.
  - **Expected:** App continues; reminders toggle stays OFF. No crash.

### A4. HealthKit Integration (Onboarding)

- [ ] **Apple Health opt-in screen** — shown before biometrics setup.
  - **Expected:** iPad should skip this screen (auto-skip in code). iPhone shows two buttons: "Import" and "Skip".

- [ ] **Tap "Import"** (iPhone only):
  - [ ] iOS permission prompt appears.
  - [ ] Grant access to menstrual flow, symptoms, pain read/write.
  - **Expected:** "Syncing..." briefly appears, then confirms "No prior history found" (if first run) or "Imported X entries" (if Apple Health has data).

- [ ] **Tap "Skip"** → advances without importing.
  - **Expected:** No error; onboarding continues.

### A5. Biometric & PIN Setup

- [ ] **Biometric option screen** — button shows correct device capability ("Face ID / Touch ID / Passcode").
  - **Expected:** Title matches device hardware; copy explains the lockdown will auto-lock when the app backgrounded.

- [ ] **Tap "Set up Face ID"** (or Touch ID):
  - [ ] iOS biometric permission appears.
  - [ ] Grant or deny.
  - **Expected:**
    - If **granted:** App lock is active. Gesture prompts for auth on next app open. Passcode is set to a random 4-digit code (shown once, not changeable here).
    - If **denied:** App lock is NOT active; you can still set one later in Settings.

- [ ] **Tap "Use Passcode instead"** → manually enter a 4-digit PIN.
  - **Expected:** Prompts twice (set and confirm). Mismatch shows error. Confirmation → lock active.

### A6. Onboarding Completion

- [ ] **Completion celebration screen** — shows confetti/animation, "You're ready!" message, and Caelyn logo.
  - **Expected:** Tap "Let's go" or swipe up → transitions to Home tab.

- [ ] **First-time Home arrival** — if last-period date was provided:
  - [ ] Cycle ring shows cycle day (e.g., "Day 14").
  - [ ] Phase badge displays (e.g., "Fertile 🌾").
  - [ ] "Next period in X days" appears.
  - **Expected:** If the onboarding data was sparse, "Low confidence" badge appears with a hint to log more cycles.

### A7. First Prediction Reveal (One-Time Card)

- [ ] **After onboarding completion with a last-period date**, return to Home.
  - **Expected:** A **one-time celebration card** appears: "Caelyn's predictions are now live" + close button. Card dismisses and does NOT reappear on later app opens.

- [ ] **Tap the card** → scrolls to the "Coming Up" timeline.
  - **Expected:** Timeline shows predicted period, ovulation, fertile window (if applicable).

---

## B. PIN / DURESS / BIOMETRIC / UNLOCK

**Prerequisite:** App lock is configured (set during onboarding or later in Settings → Privacy & Security).

### B1. Lock at Entry

- [ ] **Close the app entirely** (swipe up from home screen or kill from app switcher).

- [ ] **Reopen Caelyn**.
  - **Expected:**
    - If **Face/Touch ID is set:** Face/Touch prompt appears immediately. App is **locked** (Home/Calendar/Insights are blurred/masked). Tap "Enter PIN" to bypass biometric.
    - If **only PIN is set:** Numeric keypad appears (locked). Cycle ring is masked behind a lock shield.

### B2. Correct PIN Unlock

- [ ] **Type the correct 4-digit PIN** (set during setup or remembered from Settings).
  - **Expected:**
    - PIN dots mask input.
    - After 4 digits → app unlocks immediately; Home content becomes sharp.
    - Enters the app. No lockout timer.

- [ ] **Incorrect PIN** → type a wrong code.
  - **Expected:**
    - After 4 digits → red shake, "Wrong PIN. X attempts remaining" message.
    - Count down: 5 attempts, then "Locked for 60 seconds."
    - Timer counts down. After 60s, PIN pad reappears. Can retry.

### B3. Duress PIN Silent Wipe

**Prerequisite:** Duress PIN is configured in Settings → Privacy & Security → Duress PIN.

- [ ] **Close app entirely**.

- [ ] **Reopen Caelyn** → lock screen shows.

- [ ] **Enter the duress PIN** (e.g., if standard PIN is "1234" and duress is "4567").
  - **Expected:**
    - No "welcome back" message.
    - App appears **completely fresh** — onboarding Welcome screen displays as if the app was never opened.
    - **All cycle data, settings, PIN configuration is GONE** (silently wiped).
    - Logging → every data field is empty.

- [ ] **Verify duress wipe is permanent** — close and reopen the app.
  - **Expected:** Onboarding Welcome appears again (no user profile). Data is truly deleted, not cached.

- [ ] **Reset the app** by completing onboarding again to restore testability.

### B4. Fail-Open (No Lock Set)

- [ ] **Remove the PIN entirely** → Settings → Privacy & Security → Manage PIN → "Remove Lock" (or during setup, choose "Not now").

- [ ] **Close and reopen Caelyn**.
  - **Expected:**
    - **No lock screen** appears.
    - Home loads immediately.
    - Cycle ring, cards, all content are live (not masked).
    - User can access Settings, Calendar, Insights without any prompt.

### B5. Biometric Retry & Fallback

**Prerequisite:** Face/Touch ID + PIN lock is configured.

- [ ] **Close app, reopen, Face/Touch prompt appears**.

- [ ] **Deliberately fail biometric** (look away from camera, wrong fingerprint, etc.) 3–5 times.
  - **Expected:**
    - After repeated failures, iOS offers "Try passcode" button (system behavior).
    - Tap it → numeric PIN keypad appears (app's fallback).

- [ ] **Enter correct PIN**.
  - **Expected:** Unlocks immediately. No timeout or secondary lock applied.

### B6. Lock Timeout on Background

- [ ] **Unlock the app** (Face ID or correct PIN).

- [ ] **Press Home, backgrounding Caelyn**.

- [ ] **Wait 30+ seconds**.

- [ ] **Reopen Caelyn**.
  - **Expected:** Lock screen reappears (or Face/Touch prompt). You must re-authenticate.

- [ ] **Reopen Caelyn within 10 seconds** (adjust timing as implemented):
  - **Expected:** May still be unlocked OR lock screen appears (depends on implementation; check LAUNCH_CHECKLIST.md for exact timeout). Consistency is what matters.

---

## C. AUTO-ERASE (PARANOID MODE) TOGGLE

**Location:** Settings → Privacy & Security → Paranoid Mode.

- [ ] **Toggle is OFF by default**.
  - **Expected:** Setting is visible, toggle shows OFF state. Copy explains "automatically erase cycle data if incorrect PIN entered N times."

- [ ] **Turn toggle ON**.
  - [ ] Confirmation dialog appears: "Erase all data after 3 wrong PINs?"
  - **Expected:** Tap "Confirm" → toggle moves to ON. Tap "Cancel" → toggle stays OFF.

- [ ] **Close Settings, return to Home, log some data** (flow, mood, note).

- [ ] **Close app, reopen, and deliberately enter wrong PIN 3 times** (while Paranoid Mode is ON).
  - **Expected:**
    - After 3rd wrong attempt: No lockout timer shown (unlike normal PIN behavior).
    - App appears to "reset" — onboarding Welcome screen appears.
    - All cycle data, profile, settings are erased.
    - PIN is still set (you can unlock with the correct PIN if you try again).

- [ ] **Turn Paranoid Mode OFF** → toggle in Settings.
  - **Expected:** Setting persists OFF. No unwanted erases on subsequent wrong PINs.

---

## D. NOTIFICATIONS DELIVERY

**Prerequisite:** Notifications permission is GRANTED in Settings → Notifications → Caelyn.

### D1. Daily Check-In Reminder

- [ ] **Open Settings → Reminders → Toggle "Daily check-in" ON**, set time to current time + 2 minutes (e.g., if it's 3:58 PM, set 4:00 PM).

- [ ] **Log a mood TODAY** (Home → Quick Actions → Mood, or Daily Log sheet).
  - **Expected:** Mood is saved. The reminder system suppresses today's check-in (since mood was logged).

- [ ] **Wait until the scheduled time** (4:00 PM in example).
  - **Expected:**
    - No notification fires for TODAY (because mood was logged).
    - **Tomorrow at 4:00 PM**, a notification should fire: **"Today's check-in"** or **"Caelyn reminder · Tap to log how you're feeling."** (depending on private-notifications setting).

- [ ] **Open the notification**:
  - **Expected:** App opens to Home, Daily Log sheet auto-pops for today's date. (Or calendar sheet if coming from background, depending on notification routing.)

### D2. Daily Check-in — Quiet Hours

- [ ] **Settings → Reminders → Quiet Hours: 22:00–07:00** (default or user-configured).

- [ ] **Set the daily check-in reminder to fire at 23:30 (11:30 PM)**.

- [ ] **Wait for that time** (or manually adjust device time if testing).
  - **Expected:**
    - Notification **does NOT fire at 23:30** (inside quiet hours).
    - **Next morning at 07:00 (7 AM)**, the notification fires instead (shifted out of quiet hours).
    - Body says "Today's check-in."

- [ ] **Change device time back to now** after testing.

### D3. Period-Start Reminder

- [ ] **Settings → Reminders → Period start reminder: ON, offset 1 day before**.

- [ ] **Cycle Settings**: Set last-period start to a date that makes the next period 2 days from now (e.g., if today is June 28 and avg cycle is 28, set last period to May 31).

- [ ] **Wait or adjust device time** to the reminder time.
  - **Expected:**
    - Notification fires 1 day before predicted period: **"Your period may start soon"** (or **"Caelyn reminder"** if private mode).
    - Tap → opens to Home, showing predicted period window highlighted.

### D4. Private Notification Wording

- [ ] **Settings → Privacy & Security → Private notifications: ON**.

- [ ] **Set any reminder to fire soon** (check-in, period, medication, ovulation).

- [ ] **Wait for notification** (or test by adjusting device time).
  - **Expected:**
    - Title: **"Caelyn reminder"** (generic, not "Your period may start soon").
    - Body: **"Tap to check in."** (generic, not "How are you feeling?").
    - On lock screen, a glance reveals **nothing personal** — just that Caelyn has sent a reminder.

- [ ] **Toggle Private Notifications OFF**, then fire a reminder again.
  - **Expected:**
    - Title: **"Today's check-in"** or **"Your period may start soon"** (specific copy).
    - Body: **"How are you feeling today?"** or **"Caelyn predicts your period in a couple of days."** (specific context).

### D5. Note-to-Self Reminder

**Location:** Daily Log sheet → Notes tab → Reminder dropdown.

- [ ] **Log a note** (e.g., "Bring pain reliever") on today's entry.

- [ ] **Set reminder: "Specific date"** → pick tomorrow at 2:00 PM (or any future time).
  - **Expected:** Dropdown accepts the date. Icon/label shows "Reminder set."

- [ ] **Alternatively, set reminder: "2 days before my period"** (cycle-relative).
  - **Expected:** Dropdown shows selection. App resolves to an actual date based on next predicted period.

- [ ] **Home screen** → scroll down to "Due note reminders" card.
  - **Expected:** Tomorrow's note appears in a due-reminders card (if using date-based reminder) with the text snippet. Tap to open the entry.

- [ ] **Wait until the reminder time** (or adjust device time).
  - **Expected:**
    - Notification fires: **"A note to yourself"** or **"Caelyn reminder"** (title, depending on private mode).
    - Body: **"You left yourself a note. Tap to see it."** (never shows the actual note text on lock screen).
    - Tap → opens Daily Log sheet for that day's entry with the note visible in-app.

- [ ] **Verify private notification does NOT leak note text**:
  - [ ] Mark note reminder as done (Home card → checkmark or Daily Log sheet → close reminder).
  - [ ] Verify it does NOT appear in Notification Center after being marked done.
  - [ ] Verify the note text does NOT appear in ANY lock-screen preview.

### D6. Medication Reminder

- [ ] **Settings → Reminders → Medication reminder: ON**, set time to current time + 2 min.

- [ ] **Log medication** today (Daily Log → Advanced → Medication field).
  - **Expected:** Today's medication reminder is suppressed (same logic as check-in).

- [ ] **Tomorrow at the reminder time**:
  - **Expected:**
    - Notification fires: **"Medication"** or **"Caelyn reminder"**.
    - Interruption level is **.timeSensitive** (breaks Focus modes) — verify in iOS notification settings that Caelyn has time-sensitive permission.
    - Tap → opens Daily Log for today, Medication field visible.

### D7. Ovulation Reminder

- [ ] **Settings → Reminders → Ovulation reminder: ON**, set time.

- [ ] **Ensure last-period start is logged** (Cycle Settings).

- [ ] **App calculates next ovulation** (default: ~14 days before next period).

- [ ] **Wait for ovulation reminder time** (e.g., adjust device time to make it fire today or tomorrow).
  - **Expected:**
    - Notification: **"Ovulation window"** or **"Caelyn reminder"**.
    - Body: **"Caelyn estimates ovulation is around now."** (or private: "Tap to learn more.").
    - Tap → opens to Home, "Coming Up" timeline highlighted (showing fertile window).

### D8. Birth Control Reminder (Pill / Patch / Ring)

- [ ] **Settings → Birth Control → toggle ON**, select method (Pill / Patch / Ring).

- [ ] **Set reminder time** to current + 2 minutes.

- [ ] **Birth Control → Birth Control reminder: ON**.
  - [ ] **Pill method**: Reminder fires every day at the set time (repeating).
    - **Expected:** Notification appears daily with body "Don't forget your birth control today."
  - [ ] **Patch method** (change every 7 days): Reminder fires on days 7, 14, 21 (change days), then day 28 (insert new patch).
    - **Expected:** Notification on the next patch-change day. Tap → shows Birth Control view.
  - [ ] **Ring method** (change on days 21, 28): Similar to patch.
    - **Expected:** Notification on day 21 (remove) and day 28 (insert).

- [ ] **Log the BC action** (e.g., "took pill") → suppress tomorrow's reminder (if implementing auto-suppression).

---

## E. APPLE HEALTH INTEGRATION

**Prerequisite:** HealthKit is available on the device (iPhone, Apple Watch; NOT iPad). Caelyn has requested and been granted HealthKit permissions in iOS Settings.

### E1. Health Permissions Request

- [ ] **Settings → Health Connect → toggle "Read flow data" ON** (or first time, tap "Connect").
  - **Expected:** iOS permission sheet appears, asking for read access to Menstrual Flow.
  - [ ] Grant: Sheet dismisses, toggle shows ON.
  - [ ] Deny: Toggle stays OFF, no error.

- [ ] **Toggle "Write flow data" ON**.
  - **Expected:** iOS permission sheet for write access. Grant or deny. Toggle reflects state.

- [ ] **Open iOS Settings → Health → Data Access & Devices → Caelyn**.
  - **Expected:** Shows all three categories (read/write) that Caelyn requested. Toggles can be toggled here too (independent of Caelyn app's toggles).

### E2. Flow Export to Apple Health

- [ ] **Log a period flow** on today's entry (Daily Log → Flow: Medium/Heavy).

- [ ] **Verify in Apple Health app** → Health → Menstrual Cycle → Menstrual Flow.
  - **Expected:** Today's flow (e.g., "Medium") appears under Menstrual Flow with Caelyn as the source. Data syncs within seconds.

- [ ] **Update the flow** in Caelyn (change to "Light"), then save.

- [ ] **Check Apple Health again**:
  - **Expected:** Flow updates to "Light" in Apple Health (Caelyn performs delete-then-rewrite, so old entry is removed and new one written).

### E3. Symptom & Pain Export

- [ ] **Log symptoms** (Daily Log → Symptoms: Headache, Fatigue, etc. with severity Mild/Mod/Severe).

- [ ] **Log pain** (Daily Log → Pain: set slider + select pain types like Cramps, Headache).

- [ ] **Check Apple Health** → Health → Symptoms / Pain categories.
  - **Expected:** Logged symptoms appear under their respective Apple Health categories (Headache, Fatigue, etc.) with severity level (Mild = 1, Moderate = 2, Severe = 3). Pain entries appear under Pain categories.

- [ ] **Update severity**, resave, and verify Apple Health updates.

### E4. Flow Import from Apple Health

- [ ] **Use Apple Health app or a HealthKit-capable app** (e.g., Livia, Clue export to Apple Health) to manually add a flow entry for a past date (e.g., 10 days ago: Medium flow).

- [ ] **Caelyn → Calendar → tap the past date**.
  - **Expected:** Calendar may not show the imported entry immediately (Caelyn doesn't auto-import on every sync; import is opt-in via Settings → Import data).

- [ ] **Settings → Import data → "Import from Apple Health"**.
  - **Expected:**
    - Button opens a sheet or confirmation dialog.
    - Caelyn fetches flow data from Apple Health for the past 90+ days.
    - "Importing..." → "Found X entries, imported Y (updated Z)."
    - Imported entries appear in Calendar and Daily Log for those dates.

- [ ] **Verify imported data doesn't duplicate**:
  - [ ] Close and reopen the app.
  - [ ] Run import again.
  - **Expected:** "Found X entries, no new data" or similar (no re-import of same day).

### E5. HealthKit Availability Check

- [ ] **On an iPad** (if available):
  - **Expected:** HealthKit Connect section is **hidden or disabled** in Settings (Health Connect is iPhone-only).

- [ ] **On an unsupported device**:
  - **Expected:** "Apple Health isn't available on this device" message appears where Health Connect would be.

### E6. Wrist-Temperature (Apple Watch Series 8+ only)

**Prerequisite:** Apple Watch Series 8 or later, paired with iPhone, worn overnight.

- [ ] **Enable Apple Health read access** for Caelyn (wrist temp is read-only).

- [ ] **Wear the Apple Watch overnight** — it collects sleeping wrist temperature.

- [ ] **Caelyn app → Insights tab** → scroll down to "Temperature Shift" card (Pro feature).
  - **Expected:**
    - BBT chart loads with any wrist-temp data from Apple Health.
    - Data points appear as dots/line on chart (if any wrist temp data exists).
    - No errors if no data is available yet.

- [ ] **Chart interpretation**:
  - **Expected:** Shows temperature trend over the past 40 days. Shift-detection is in code (int-3); visual confirmation just needs the data to plot correctly.

---

## F. SWIFTDATA MIGRATION & DEDUPLICATION

**Note:** This is a destructive test; use a backup build or VM instance.

### F1. Pre-Migration Build Setup

- [ ] **Xcode → checkout a prior commit** (before the migration was deployed) or use a tagged "pre-Phase6" release build.

- [ ] **Build and install on a device** (not simulator, to test real file persistence).

- [ ] **Log 2–3 weeks of data**:
  - [ ] At least one full cycle (period + ovulation window).
  - [ ] Multiple moods, symptoms, pain, flow entries.
  - [ ] A note-to-self with a reminder.
  - [ ] Ideally, 2–3 entries on the **same calendar day** (to test dedup).

- [ ] **Settings → Cycle → verify** average cycle and period lengths are learned/set.

- [ ] **Close and fully quit the app**.

### F2. Upgrade Build

- [ ] **Xcode → checkout the current (post-migration) commit**.

- [ ] **Build and install over the old build** (same app on device).

- [ ] **Press Home and let iOS close the app, then reopen Caelyn**.
  - **Expected:**
    - App launches without crashing.
    - Home loads with all prior data intact.
    - Cycle ring, predicted period, all cards display.
    - No "store failed" banner or error message.

### F3. Deduplication Verification

- [ ] **Calendar tab → view the dates where you logged multiple entries** (if you added same-day duplicates intentionally).
  - **Expected:**
    - Only **one entry per calendar day** is shown.
    - Data from all duplicates is **merged** (arrays unioned, newest scalar values win).
    - No duplicate entries appear.

- [ ] **Daily Log sheet for a merged day**:
  - **Expected:**
    - All symptoms, moods, pain, flow from the duplicates are present.
    - No data loss.

### F4. Reminders & Notifications Survive

- [ ] **Settings → Reminders**:
  - **Expected:** Reminder toggles and times are preserved exactly as before the migration.

- [ ] **Daily Log → Notes → check note reminders**:
  - **Expected:** Any note-to-self reminders on entries are intact (rule and scheduled time).

- [ ] **Wait for next scheduled reminder**:
  - **Expected:** Notification fires correctly, using migrated data.

### F5. Rollback Test

- [ ] **Downgrade back to the pre-migration build** (reinstall the old version).

- [ ] **Reopen Caelyn on the device**.
  - **Expected:**
    - Old store opens **without crashing**.
    - All migrated-and-back data is present (or as much as SwiftData's automatic downgrade allows).

---

## G. WIDGETS

**Prerequisites:**
- **Home screen widgets:** Long-press home screen, tap + to add a widget, select Caelyn.
- **Lock-screen widgets:** Long-press lock screen, tap + to add accessory widget.
- **Standby:** iOS 17+ device; plug device into charger, rotate to landscape on Standby mode.

### G1. Small Widget (Home)

- [ ] **Add small widget to home screen**.
  - **Expected:**
    - Displays cycle day (e.g., "Day 14").
    - Displays phase badge (e.g., "Fertile 🌾").
    - Displays days until next period (e.g., "Period in 14 days").
    - Layout is compact, readable.

- [ ] **Tap the widget**.
  - **Expected:** Opens Caelyn app to Home tab (or Calendar, depending on routing).

- [ ] **App logs new data** (e.g., mood, flow).
  - **Expected:** Widget refreshes within seconds to reflect new cycle day or phase (if midnight has passed).

- [ ] **No real cycle data yet** (fresh onboarding):
  - **Expected:** Widget shows honest empty state ("Start tracking" or similar), **not** fabricated numbers.

### G2. Medium Widget (Home · Pro)

- [ ] **Add medium widget to home screen**.
  - **Expected:**
    - Displays cycle ring + phase badge.
    - Shows upcoming events (period, ovulation, PMS) with dates/counts.
    - Multiple lines of info without cramping.

- [ ] **Multiple upcoming events**:
  - **Expected:** Scrolls or displays timeline of next 3–4 events (e.g., Ovulation on Jun 30, Period on Jul 14).

### G3. Large Widget (Home · Pro)

- [ ] **Add large widget to home screen**.
  - **Expected:**
    - Displays full cycle ring + phase info.
    - Shows 5+ upcoming events with full details.
    - Readable at a glance from home screen.

### G4. Standby Mode (iOS 17+, Pro)

- [ ] **Plug iPhone into charger, rotate to landscape, or wait for idle lock screen to auto-Standby**.
  - **Expected:** Caelyn's large widget displays as Standby widget (full-screen dynamic).

- [ ] **Widget shows**:
  - [ ] Cycle ring (animated).
  - [ ] Current phase & cycle day.
  - [ ] Next upcoming event (period, ovulation, etc.).

- [ ] **Tap widget** → Caelyn opens to Home tab.

- [ ] **No data scenario**:
  - **Expected:** Standby widget shows empty state, not fabricated data.

### G5. Lock-Screen Accessories (Pro)

#### G5a. Circular Widget

- [ ] **Long-press lock screen → + → Caelyn → Circular**.
  - **Expected:**
    - Displays cycle ring (circular arc showing cycle progress).
    - Shows cycle day in center (e.g., "14").
    - Fits in lock-screen circular accessory slot.

- [ ] **Tap widget** → app opens.

#### G5b. Rectangular Widget

- [ ] **Long-press lock screen → + → Caelyn → Rectangular**.
  - **Expected:**
    - Displays cycle day + phase badge + days until period.
    - Fits in lock-screen rectangular accessory slot.

#### G5c. Hide Preview on Lock Screen

- [ ] **Settings → Privacy & Security → Hide preview on lock screen: ON**.

- [ ] **Look at lock-screen accessory widgets**:
  - **Expected:**
    - Widgets are **blurred or pixelated** when locked (iOS default behavior for protected content).
    - When you unlock the device, widgets become sharp.

### G6. Midnight Rollover

- [ ] **Add any widget to home screen**.

- [ ] **Wait until midnight (or adjust device time to 23:59)**.

- [ ] **At midnight**:
  - **Expected:**
    - Cycle day increments by 1 automatically (e.g., Day 14 → Day 15).
    - Phase may shift if crossing a phase boundary.
    - Widget updates **without the app being opened** or refreshed manually.

- [ ] **Adjust device time back to now** after testing.

---

## H. APPLE WATCH APP + SYNC

**Prerequisites:** Apple Watch paired with iPhone, Caelyn installed on both.

### H1. Watch App Launch

- [ ] **Open Caelyn app on Apple Watch**.
  - **Expected:**
    - Displays "No cycle data yet" empty state (if this is the first sync).
    - Shows message: "Open Caelyn on your iPhone to sync your cycle to your watch."
    - Quick Log button is visible.

### H2. iPhone-to-Watch Sync (Pro)

- [ ] **Ensure last-period start is set** (Cycle Settings on iPhone).

- [ ] **iPhone Caelyn → Home tab**.
  - **Expected:** Home loads with cycle data (ring, phase, upcoming events).

- [ ] **Force watch connectivity** by backgrounding and reopening iPhone Caelyn, or by opening Watch app.

- [ ] **Watch Caelyn → refresh or reopen**.
  - **Expected:**
    - Cycle ring appears (same color + progress as iPhone).
    - Cycle day, phase badge, and stats display.
    - Upcoming events show (e.g., "Period in 14 days").

### H3. Watch Quick Log

- [ ] **Watch app → tap "Log" button**.
  - **Expected:** Quick Log sheet appears.

- [ ] **Tap flow selector** → choose Medium/Heavy.
  - **Expected:** Flow is selected, icon displays the choice.

- [ ] **Tap pain slider** (0–10) → adjust.
  - **Expected:** Slider updates.

- [ ] **Tap mood** (5–8 moods) → select one (e.g., 😄).
  - **Expected:** Mood is selected.

- [ ] **Tap "Save"** or swipe to submit.
  - **Expected:**
    - "Saving..." briefly appears.
    - Sheet dismisses.
    - Watch home refreshes to show new data.

- [ ] **Return to iPhone Caelyn** (or check Calendar).
  - **Expected:**
    - Today's entry in Daily Log includes the logged flow, pain, mood from watch.
    - Data syncs within 10 seconds (Watch Connectivity).

### H4. Watch-to-iPhone Sync (Pro)

- [ ] **Log flow/mood on Apple Watch** (via Quick Log).

- [ ] **iPhone Caelyn → Calendar → tap today**.
  - **Expected:**
    - Daily Log sheet shows the watch-logged flow and mood.
    - Timestamps may differ (watch time vs. iPhone time), but data is present.

### H5. Empty State (No Data)

- [ ] **On iPhone, delete all data** (Settings → Delete all data).
  - **Expected:** Profile and entries are wiped.

- [ ] **Watch app → Caelyn**:
  - **Expected:** "No cycle data yet" empty state appears (not stale data).

---

## I. STOREKIT SANDBOX: PRODUCTS & PURCHASE

**Prerequisites:**
- App configured with App Store Connect sandbox account (or local .storekit file).
- Three product IDs: monthly, yearly, lifetime (must match `PurchaseService.ProductID`).
- Sandbox test account with appropriate entitlements.

### I1. Load Products

- [ ] **Open Caelyn Paywall** → Settings → Upgrade to Pro (or Home → Soft Paywall card).

- [ ] **Paywall sheet appears**.
  - **Expected:**
    - "Loading products..." briefly shows (or products load instantly).
    - Three product tiles appear: Monthly ($3.99), Yearly ($19.99), Lifetime ($49.99).
    - All prices and descriptions load correctly.

- [ ] **Verify product details**:
  - [ ] Monthly shows "7-day free trial" label (if eligible).
  - [ ] Yearly shows savings badge (e.g., "Save 36%").
  - [ ] Lifetime shows "One-time purchase" or similar.

### I2. Purchase Monthly (with Trial)

- [ ] **Select Monthly tier**.

- [ ] **Tap "Start Free Trial"** (if eligible) or "Subscribe".
  - **Expected:**
    - iOS purchases sheet appears.
    - Shows Caelyn subscription, price, trial period, auto-renewal terms.

- [ ] **Tap "Subscribe"** on the purchase sheet.
  - **Expected:**
    - Payment processes (sandbox uses test card automatically).
    - Paywall sheet dismisses.
    - **isPro** is now true; pro-only features unlock (Pro badge removed, Pro charts appear in Insights, etc.).

- [ ] **Settings → check status**:
  - **Expected:** Shows "You have Caelyn Pro" or subscription renewal date (if app implements this view).

### I3. Purchase Yearly

- [ ] **Repeat onboarding** or reset to free tier (for testing purposes).

- [ ] **Paywall → Select Yearly tier → Subscribe**.
  - **Expected:**
    - Trial is offered if eligible.
    - Purchase processes.
    - isPro becomes true.

### I4. Lifetime Purchase

- [ ] **Reset to free (if needed)**.

- [ ] **Paywall → Select Lifetime → Tap "Buy Now"** (no trial for one-time).
  - **Expected:**
    - iOS purchase sheet shows $49.99, one-time charge.
    - After purchase, isPro is true; lifetime access granted.
    - No renewal date (lifetime = permanent).

### I5. Restore Purchases

- [ ] **Paywall → find "Restore Purchases" button** (usually bottom of sheet).

- [ ] **Tap it**.
  - **Expected:**
    - "Restoring..." message.
    - If the test account has an active subscription:
      - "You're all set with Caelyn Pro" appears.
      - isPro stays true or becomes true.
    - If no subscription:
      - "No active subscription found" message.
      - User remains free tier.

### I6. Trial Eligibility Check

- [ ] **Create a fresh sandbox account** (via TestFlight or App Store Connect sandbox).

- [ ] **Open Paywall → Monthly or Yearly**.
  - **Expected:** "7-day free trial" label appears.

- [ ] **After claiming the trial on one subscription**, create a new sandbox account.

- [ ] **On the new account, Paywall → Month/Year → check label**:
  - **Expected:** "7-day free trial" is still shown (fresh account = eligible).

- [ ] **On the original account, clear purchase history** (App Store Settings → reset purchases, if available in sandbox).

- [ ] **Reopen Paywall**:
  - **Expected:** Trial label disappears or shows "Not eligible"; paid pricing is the only option.

### I7. Offline Entitlement Caching

- [ ] **Turn off device networking** (Airplane mode).

- [ ] **Caelyn is in Pro tier** (from a prior purchase).

- [ ] **Open Settings → Pro features should still show as unlocked**.
  - **Expected:**
    - Insights charts, Pro-gated views, etc. remain accessible.
    - Caelyn uses cached entitlements from the last successful transaction.

- [ ] **Turn off Airplane mode**, sync app to server.
  - **Expected:** Entitlements refresh and match server truth.

---

## J. ON-DEVICE AI SUMMARY (Apple Intelligence)

**Prerequisites:** iPhone 16+ or iPhone 15 Pro with Apple Intelligence enabled (iOS 26+, if available).

### J1. AI Summary on Insights Tab (Pro)

- [ ] **Log 3+ complete cycles** of data (flow, symptoms, moods, etc.).

- [ ] **Insights tab → scroll to "Cycle Summary" card** (visible in Pro tier).
  - **Expected:**
    - Card title: "Private Intelligence" or similar.
    - Summary text loads below.

- [ ] **Verify AI-generated summary** (on iOS 26+):
  - **Expected:**
    - Summary is 2–3 sentences, warm tone (e.g., "Your cycle averages 28 days. You've logged consistent energy dips in the luteal phase. That's your body's natural rhythm.").
    - Uses structured facts only (cycle length, phase, predictions), never free-form notes.
    - Takes 1–3 seconds to load (on-device processing).

### J2. Fallback on Older Devices

- [ ] **On iPhone 15 or earlier**, or if Apple Intelligence is unavailable:
  - **Expected:**
    - Summary displays immediately (no delay).
    - Text is deterministic template: e.g., "Your average cycle is 28 days. You're in the ovulation phase, with your period expected in 10 days."
    - No "Loading..." spinner; fallback is instant.

### J3. AI Graceful Failure

- [ ] **Disable Apple Intelligence** (Settings → Apple Intelligence & Siri, if available).

- [ ] **Insights → Cycle Summary card**:
  - **Expected:**
    - Fallback template appears immediately.
    - No error message or spinner.

- [ ] **Re-enable Apple Intelligence**.
  - **Expected:**
    - Next app launch, AI summary is used again (if iOS 26+).

---

## K. iCLOUD SYNC (Two-Device Test, Optional)

**Note:** Sync is **opt-in and OFF by default**. Only test this if it's enabled in the build or you've manually turned it on.

### K1. Enable Sync

- [ ] **Settings → iCloud Backup → toggle "iCloud Sync" ON**.
  - **Expected:**
    - Confirmation dialog: "Turn on iCloud sync to mirror your data across devices?"
    - Tap "Enable" → sync activates.
    - Sync status: "On" or similar label.

- [ ] **Verify sync is OFF by default** (on fresh installs):
  - **Expected:** Toggle shows OFF on first app launch.

### K2. Two-Device Mirror

- [ ] **Device A: Enable sync, log a few entries** (flow, mood, note).

- [ ] **Device B: Open Caelyn, enable sync**.
  - **Expected:** Wait 10–30 seconds for CloudKit sync to resolve.

- [ ] **Device B: Calendar → check the dates logged on Device A**.
  - **Expected:**
    - Entries from Device A appear on Device B.
    - No duplicates.

- [ ] **Device B: Log a new entry**, then check Device A.
  - **Expected:** Device A's Calendar shows Device B's new entry within 10–30 seconds.

### K3. Sync OFF Data Stays Local

- [ ] **Device A: Sync is OFF** (default state).

- [ ] **Log entries on Device A** (flow, mood, etc.).

- [ ] **Device B: Open Caelyn, enable sync**.
  - **Expected:**
    - Device B sees **no data from Device A** (Device A was local-only).
    - Device B's sync starts fresh.

- [ ] **Device A: Enable sync after Device B**.
  - **Expected:**
    - CloudKit merges both devices' data, with timestamps determining precedence.
    - No data loss; both sets of entries are synced.

### K4. CloudKit Schema Push

- [ ] **If not already done:** Xcode → Caelyn project → iCloud (CloudKit) Signing & Capabilities.
  - [ ] Ensure container ID matches `Persistence.cloudKitContainerID` (`iCloud.smallpanta-icould.com.caelynperiodtracker`).
  - [ ] Fetch CloudKit schema.
  - [ ] Push schema to **Production** (in CloudKit Console).
  - **Expected:** Schema is live; sync operations succeed.

---

## L. SHAREABLE CARD

**Location:** Home tab or Insights tab; look for "Share" buttons or a Share icon.

### L1. Generate Shareable Card

- [ ] **Home or Insights → locate "Share" button** (or similar).

- [ ] **Tap it**.
  - **Expected:** Sheet appears with options:
    - Moment selector or direct card preview.
    - Options: "One week of listening", "Caelyn learned my rhythm", "Privacy first", phase-specific cards, etc.

- [ ] **Select a moment** (e.g., "Caelyn learned my rhythm").
  - **Expected:**
    - Card preview renders on-device.
    - Shows warm, non-clinical copy: "Caelyn learned my rhythm — It knows my patterns — privately, just for me."
    - No exact cycle data, dates, or medical numbers visible.

### L2. Share Sheet

- [ ] **Tap "Share" button** on the card preview**.
  - **Expected:**
    - iOS share sheet appears (Messages, Mail, Instagram, Save to Photos, AirDrop, etc.).
    - Only the **rendered image** is shared, not cycle data.

- [ ] **Select "Save to Photos"**.
  - **Expected:**
    - Card image is saved to Photo Library.
    - Verify in Photos app that the card image (only the image, not associated metadata) appears.

- [ ] **Select "Messages"** (if available).
  - **Expected:**
    - New message compose sheet opens.
    - Card image is attached.
    - No personal data is shared.

### L3. Privacy Verification

- [ ] **Share the card via any method**.

- [ ] **Recipient opens the image on another device/app**:
  - **Expected:**
    - Image shows only public-facing branding + vibe (no dates, no numbers, no personal health data).
    - Recipient cannot infer the user's cycle or health status from the card alone.

---

## M. BIOMETRIC & LOCK SPECIAL CASES

### M1. Change PIN

- [ ] **Settings → Privacy & Security → Manage PIN → "Change PIN"**.

- [ ] **Enter old PIN**.
  - **Expected:** Unlocked; proceed to new PIN entry.

- [ ] **Enter new PIN twice** (set and confirm).
  - **Expected:**
    - "PIN changed successfully" confirmation.
    - New PIN is active immediately.

- [ ] **Close and reopen app** with new PIN.
  - **Expected:** New PIN unlocks the app.

### M2. Remove PIN

- [ ] **Settings → Privacy & Security → Manage PIN → "Remove Lock"**.

- [ ] **Confirmation dialog** appears.
  - **Expected:** Tap "Remove" → lock is disabled.

- [ ] **Close and reopen app**.
  - **Expected:** No lock screen; app opens immediately.

### M3. Set Duress PIN

- [ ] **Settings → Privacy & Security → Duress PIN → "Set"**.

- [ ] **Enter a 4-digit PIN** (different from main PIN).
  - **Expected:** Confirmation prompt. Set duress PIN.

- [ ] **Use duress PIN to unlock** (as tested in section B3).
  - **Expected:** Silent wipe occurs.

### M4. Biometric Added After PIN

- [ ] **App lock is set via PIN only**.

- [ ] **Settings → Privacy & Security → Add Face ID / Touch ID**.

- [ ] **Grant iOS biometric permission**.
  - **Expected:**
    - Biometric unlock is now active (Face/Touch).
    - PIN is still available as fallback (tap "Enter PIN").

---

## N. EXPORT & DATA BACKUP

### N1. CSV Export (Free)

- [ ] **Settings → Export data → select "CSV" and date range** (3 months, 1 year, or all).

- [ ] **Tap "Export"**.
  - **Expected:**
    - Share sheet appears with CSV file.
    - File name: something like "caelyn_export_20260628.csv".

- [ ] **Select "Save to Files"** and inspect the CSV.
  - **Expected:**
    - Headers: date, flow, pain, symptoms, mood, energy, notes, temperature, etc.
    - Each row is a logged day.
    - RFC 4180 compliant (proper escaping, CRLF line endings, etc.).

### N2. PDF Report (Pro)

- [ ] **Settings → Export data → select "PDF Clinical Report" and date range**.

- [ ] **Tap "Export"**.
  - **Expected:**
    - Share sheet appears with PDF file.
    - File name: "caelyn_clinical_report_<date>.pdf".

- [ ] **Open PDF**:
  - **Expected:**
    - **Page 1:** Title, summary (cycle length, period length, top insights).
    - **Page 2:** Cycle history timeline (bars showing cycle/period lengths and trends).
    - **Page 3–N:** Charts (cycle-length trend, period-length bar, pain trend, etc.).
    - **Final pages:** Table of all logged entries (date, flow, pain, symptoms, mood, temperature, notes).
    - **No personal dates** if redaction mode is on (check if implemented).

---

## O. DYNAMIC TYPE & ACCESSIBILITY

### O1. Large Font Sizes

- [ ] **Device Settings → Accessibility → Display & Text Size → Increase font size** (set to large, e.g., 200%).

- [ ] **Caelyn: Home tab**.
  - **Expected:**
    - Text is readable and scaled up.
    - No clipping or overlap (may require scroll).
    - Cycle ring and cards adapt gracefully.

- [ ] **Calendar, Daily Log, Insights**:
  - **Expected:** All tabs scale appropriately. No crashes.

### O2. VoiceOver

- [ ] **Device Settings → Accessibility → VoiceOver: ON**.

- [ ] **Swipe through Home tab, Calendar, Daily Log**.
  - **Expected:**
    - All elements have accessibility labels (cycle day, phase, upcoming events, buttons).
    - Reading order is logical.
    - No silent unlabeled elements.

- [ ] **Tap lock screen with VoiceOver on**:
  - **Expected:**
    - "App locked" or similar message.
    - PIN pad is accessible; tapping buttons reads their numbers.

---

## P. STRESS TEST: DELETE ALL DATA

### P1. Two-Step Confirmation

- [ ] **Settings → Data → Delete all data**.

- [ ] **First confirmation dialog** appears: "Delete all data? Every entry, your profile, and all settings will be erased."
  - **Expected:** Tap "Continue" (destructive button) or "Cancel".

- [ ] **Second confirmation dialog** appears: "This cannot be undone. Delete everything?"
  - **Expected:** Tap "Delete All" to proceed or cancel.

- [ ] **After confirmation**:
  - **Expected:**
    - All entries deleted.
    - Profile (cycle length, last period, settings) reset to defaults.
    - App returns to onboarding Welcome screen.
    - All notifications cancelled.
    - HealthKit data **is not deleted** (only Caelyn's local data is wiped; HealthKit data remains in Apple Health).

---

## Q. PRE-SUBMISSION FINAL CHECKS

### Q1. No Crashes or Hangs

- [ ] **Force-quit and reopen the app 5 times** — each time verify Home loads within 3 seconds.

- [ ] **Log a quick entry** → close → reopen → verify data persists.

- [ ] **Open each tab** (Home, Calendar, Insights, Settings) and scroll to the bottom.
  - **Expected:** No crashes, no spinners that hang indefinitely.

### Q2. Notifications Cleanup

- [ ] **Settings → All pending notifications are cancelled** when deleting all data or turning off reminders.

- [ ] **Verify** in iOS Settings → Notifications → Caelyn that old stale reminders don't appear.

### Q3. AppStore Submission Readiness

- [ ] **Check Bundle ID** matches App Store Connect app ID (e.g., `com.caelynperiodtracker`).

- [ ] **Verify version and build** match the one you're submitting (e.g., 1.0.0, build 1).

- [ ] **Privacy manifest** is included and declares:
  - [ ] `NSPrivacyTracking: false`
  - [ ] No third-party SDKs
  - [ ] UserDefaults only, no keyloggers, etc.

- [ ] **App icons** are present for all required sizes (iPhone, App Clip, etc.).

- [ ] **Screenshots** are ready (see `screenshots/` folder or App Store seeder).

- [ ] **Supported iOS versions** (min iOS 17) are correct in project settings.

- [ ] **iCloud entitlements** are configured (if sync is enabled at launch).

---

## CHECKLIST SUMMARY

### Hardware / Device Requirements

- **iPhone:** iOS 17+ for full testing (widgets, lock-screen, Standby).
- **iPad:** Optional (some features are iPhone-only; verification in code needed).
- **Apple Watch:** Series 4+ for watch app; Series 8+ for wrist temperature.
- **Biometric device:** iPhone with Face ID or Touch ID (for PIN testing).
- **Sandbox account:** App Store Connect sandbox tester email + password.

### Features Verified

- **Onboarding:** Welcome, carousel, privacy, cycle config, health import, biometric setup.
- **PIN / Duress / Unlock:** Set, change, remove, duress wipe, fail-open, timeout, biometric retry.
- **Auto-Erase:** Paranoid mode toggle and erasing after N failed attempts.
- **Notifications:** Daily check-in, period, ovulation, medication, BC, note reminders, private phrasing, quiet hours.
- **Apple Health:** Permission request, flow/symptom/pain export, flow import, wrist temp read.
- **Migration:** Pre-Phase6 build upgrade, deduplication, reminder survival.
- **Widgets:** Small, medium, large, lock-screen circular/rectangular, Standby, midnight rollover, empty state.
- **Apple Watch:** Sync, quick log, home view, empty state.
- **StoreKit Sandbox:** Product load, monthly/yearly/lifetime purchase, restore, trial eligibility.
- **AI Summary:** Foundation Models (iOS 26+), fallback template, graceful failure.
- **iCloud Sync (optional):** Two-device mirror, local-only when off.
- **Shareable Card:** Generate, share (no data leaves device).
- **Export:** CSV, PDF report, format integrity.
- **Accessibility:** Dynamic Type, VoiceOver.
- **Final stress tests:** Delete all data, crash/hang testing, submission readiness.

---

## Post-Checklist Submission

Once all items are checked:

1. **Review the code one more time** for any debug statements or test builds.
2. **Prepare metadata** for App Store Connect (privacy policy, support URL, age rating, keywords, description).
3. **Complete agreements** (Paid Apps, banking, tax forms if not done).
4. **Build for submission** (Release configuration, no TestFlight-specific settings).
5. **Upload to App Store Connect** and complete the submission form.
6. **Submit for review** — allow 1–3 business days for App Review.

---

**Good luck with Caelyn's launch! 🌸**
