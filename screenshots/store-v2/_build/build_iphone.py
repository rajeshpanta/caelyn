#!/usr/bin/env python3
"""Caelyn's eight iPhone 6.9" App Store frames (1320x2868).

Sources come from CaelynUITests/ScreenshotTests' `testStore*` captures, run on an
iPhone 17 Pro Max simulator; see ../README.md for the exact commands.
"""

import sys
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from compose import *   # noqa

FULL = 2868   # crop to the bottom of the source so the panel always bleeds

# ─────────────────────────────────────────────────────────────────────────────
# 1 — KNOW.  The billboard. Deep plum so it punches at thumbnail size, the ring
#     cropped tight enough that "Day 14" is legible in search results, and the
#     two things a shopper cannot get from Flo or Clue stated as badges.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(PLUM)
y = headline(d, "Always know", "where you are", 210,
             ink="#E3C6E7", accent=WHITE, size=130, light_size=82)
y = pills(c, d, ["Private on device", "No account needed"], y + 34,
          fg=PLUM, bg="#F7EBF9")
place(c, "S1_Home.png", (50, 470, 1270, FULL), y + 80,
      width=1240, bleed=True)
save(c, "01-know.png")

# ─────────────────────────────────────────────────────────────────────────────
# 2 — IS THIS NORMAL.  Promoted from slot 3: it is the question this audience
#     actually types into a search box, and the typical-range table is the one
#     thing in Caelyn no rival surfaces this directly.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(SAGE)
y = headline(d, "The question nobody answers", "Is this normal?", 210,
             ink="#4C6E52", accent=INK, size=124, light_size=68)
place(c, "S2_PhaseGuide.png", (100, 700, 1220, FULL), y + 96,
      width=1240, bleed=True)
save(c, "02-normal.png")

# ─────────────────────────────────────────────────────────────────────────────
# 3 — PRIVACY.  Near-black: the 2026 store is high-contrast, and for the claim
#     the whole product rests on, serious beats pastel. v1 showed four paragraphs
#     of body copy, which at thumbnail size is grey mush; this shows the claim,
#     one proof card, and nothing else.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(INK)
y = headline(d, "No server. No account. No exceptions.", "It never leaves\nyour phone", 210,
             ink="#C6A2CB", accent=WHITE, size=118, light_size=60)
breakout(c, d, "Private by architecture",
         "Caelyn has no database, no server and no cloud of its own. "
         "There is nothing for anyone to hand over — not even us.",
         y + 70, ink=INK, accent=PLUM)
place(c, "S3_Privacy.png", (50, 860, 1270, FULL), y + 430,
      width=1240, bleed=True)
save(c, "03-private.png")

# ─────────────────────────────────────────────────────────────────────────────
# 4 — PATTERNS.  The stat grid is the most thumbnail-legible screen in the app:
#     four big numbers. Lavender stops the gallery going plum-heavy.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(LAVENDER)
y = headline(d, "Your numbers,", "not the textbook's", 210,
             ink=PLUM, accent=INK, size=108, light_size=76)
place(c, "S4_Insights.png", (50, 560, 1270, FULL), y + 96,
      width=1240, bleed=True)
save(c, "04-patterns.png")

# ─────────────────────────────────────────────────────────────────────────────
# 5 — LOG.  v1 shot this screen empty — flow "None", pain 0/10, nothing ticked —
#     on the one frame whose job is to show a day fully logged. This uses a real
#     logged period day instead.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(BLUSH)
y = headline(d, "However the day went,", "log how you feel", 210,
             ink="#B4677A", accent=INK, size=118, light_size=74)
place(c, "S6b_LoggedDaySymptoms.png", (50, 280, 1270, FULL), y + 96,
      width=1240, bleed=True)
save(c, "05-log.png")

# ─────────────────────────────────────────────────────────────────────────────
# 6 — CALENDAR.  Colour does the work, so the headline stays out of the way.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(CREAM)
y = headline(d, "Every cycle,", "at a glance", 210,
             ink="#D98496", accent=INK, size=124, light_size=80)
place(c, "S5_Calendar.png", (50, 460, 1270, FULL), y + 96,
      width=1240, bleed=True)
save(c, "06-calendar.png")

# ─────────────────────────────────────────────────────────────────────────────
# 7 — SWITCH.  Entirely new. Most installs in this category are switchers, and
#     naming the apps Caelyn reads from is a concrete promise no v1 frame made.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(WARMSAND)
y = headline(d, "Leaving another app?", "Bring it with you", 210,
             ink="#9A6B3E", accent=INK, size=112, light_size=74)
place(c, "S7_BringHistory.png", (50, 980, 1270, FULL), y + 96,
      width=1240, bleed=True)
save(c, "07-switch.png")

# ─────────────────────────────────────────────────────────────────────────────
# 8 — DOCTOR.  The closer: the reason to still be logging in month six.
# ─────────────────────────────────────────────────────────────────────────────
c, d = frame(PLUM)
y = headline(d, "Years of it, in one file", "Take it to\nyour doctor", 210,
             ink="#E3C6E7", accent=WHITE, size=124, light_size=68)
place(c, "S8_Export.png", (50, 290, 1270, FULL), y + 96,
      width=1240, bleed=True)
save(c, "08-doctor.png")

print("\ndone")
