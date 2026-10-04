#!/usr/bin/env python3
"""Caelyn's eight iPhone 6.9" frames (1320x2868). See compose.py for the why.

Every crop is a MEASURED card boundary — found by detecting where the app's
white cards sit against its cream ground, then checking the two dense screens by
eye. Guessed crops are what opened frames mid-sentence. Placement goes through
`stack()` so a piece can never run off the bottom edge.

Two or three pieces per frame, never more. The temptation is to show everything;
what reads at 250px in a search grid is a few large things with air around them.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from compose import *   # noqa

# Deeper than the app's own tints, because three frames sit side by side at
# roughly 250px in search results and a pale wash disappears there.
ROSE  = "#F6C6D1"
MINT  = "#C2E0CA"
LILAC = "#D8CDF6"
SAND  = "#EFD2B2"
SHELL = "#FADCE1"

# ── 1 · KNOW ────────────────────────────────────────────────────────────────
# The ring is the app's face, so it runs big; the quick actions underneath show
# that logging is four taps; the seal says the thing no rival can say.
c, d = frame(ROSE, "#FFF4F1")
y = headline(d, "Always know", "where you are", 170,
             sans_color="#8A4F61", serif_color=INK, sans_size=86, serif_size=150)
# Pills rather than a round seal: a seal large enough to read had nowhere to sit
# that was not on top of the tab bar.
y = pills(c, d, ["Private on device", "No account"], y + 26, fg=PLUM, bg=WHITE, size=40)
# The ring IS the frame — one panel, running off the edge. Splitting it in two
# cut the hero card's own paragraph in half at both ends.
stack(c, "S1_Home.png",
      [(50, 470, 1270, 2868)],
      top=y + 76, width=1105, radius=56, blur=40, bleed_last=True)
save(c, "01-know.png")

# ── 2 · IS THIS NORMAL ──────────────────────────────────────────────────────
c, d = frame(MINT, "#F1FAF3")
headline(d, "The question nobody answers", "Is this normal?", 170,
         sans_color="#3B6647", serif_color=INK, sans_size=66, serif_size=144)
stack(c, "S2_PhaseGuide.png",
      [(100, 740, 1220, 1180),     # "Today for you", to the end of the card
       (100, 1400, 1220, 2868)],   # the whole typical-range table, running off
      top=580, width=1105, gap=62, angles=[-1.2, 0], radius=48, bleed_last=True)
save(c, "02-normal.png")

# ── 3 · PRIVACY ─────────────────────────────────────────────────────────────
c, d = frame(LILAC, "#F6F2FF")
y = headline(d, "No server. No account. No exceptions.", "It never leaves\nyour phone", 165,
             sans_color="#4E4170", serif_color=INK, sans_size=58, serif_size=124)
y = pills(c, d, ["No ads", "No trackers", "Nothing sold"], y + 26, fg=PLUM, bg=WHITE, size=38)
stack(c, "S3_Privacy.png",
      [(50, 850, 1270, 2868)],     # every promise, running off the edge
      top=y + 80, width=1105, radius=48, bleed_last=True)
save(c, "03-private.png")

# ── 4 · PATTERNS ────────────────────────────────────────────────────────────
# The four numbers are the picture, so they get the room; one learned pattern
# underneath shows where the numbers come from.
c, d = frame(SAND, "#FFF6EC")
headline(d, "Your numbers,", "not the textbook's", 170,
         sans_color="#80592E", serif_color=INK, sans_size=78, serif_size=126)
cutout(c, "S4_Insights.png", (80, 545, 640, 825), 585, (348, 1010), angle=-2.0, radius=44, blur=28)
cutout(c, "S4_Insights.png", (675, 545, 1245, 825), 585, (972, 930), angle=1.8, radius=44, blur=28)
cutout(c, "S4_Insights.png", (80, 880, 640, 1160), 585, (348, 1430), angle=1.4, radius=44, blur=28)
cutout(c, "S4_Insights.png", (675, 880, 1245, 1160), 585, (972, 1350), angle=-1.6, radius=44, blur=28)
stack(c, "S4_Insights.png",
      [(50, 1420, 1265, 2868)],    # Patterns, and what Caelyn learned, running off
      top=1680, width=1105, radius=46, bleed_last=True)
save(c, "04-patterns.png")

# ── 5 · LOG ─────────────────────────────────────────────────────────────────
c, d = frame(SHELL, "#FFF4F2")
headline(d, "However the day went,", "log how you feel", 170,
         sans_color="#96526A", serif_color=INK, sans_size=74, serif_size=134)
stack(c, "S6b_LoggedDaySymptoms.png",
      [(50, 1100, 1270, 1400),     # flow pills, Medium chosen
       (50, 1400, 1270, 1800),     # pain 5/10 + where does it hurt
       (50, 2050, 1270, 2560)],    # the symptom grid
      width=1105, top=0, gap=62, angles=[-1.3, 1.1, -0.8], radius=46,
      center_in=(560, 2868))
save(c, "05-log.png")

# ── 6 · CALENDAR ────────────────────────────────────────────────────────────
c, d = frame("#F9CFD7", "#FFF5F2")
headline(d, "Every cycle,", "at a glance", 170,
         sans_color="#9B5668", serif_color=INK, sans_size=78, serif_size=140)
stack(c, "S5_Calendar.png",
      [(50, 396, 1270, 1264),      # the month grid in colour
       (50, 1860, 1270, 2868)],    # September summary, running off
      top=580, width=1125, gap=74, angles=[-1.0, 0], radius=52, blur=40,
      bleed_last=True)
save(c, "06-calendar.png")

# ── 7 · SWITCH ──────────────────────────────────────────────────────────────
c, d = frame(LILAC, "#F7F3FF")
y = headline(d, "Leaving another app?", "Bring it with you", 170,
             sans_color="#4E4170", serif_color=INK, sans_size=74, serif_size=130)
y = note(d, "Nothing you have already logged will change.", y + 22, "#4E4170", size=42)
# One run, not two: the float above kept catching the tail of a paragraph
# rather than a whole card, and the list of apps is the argument anyway.
stack(c, "S7_BringHistory.png",
      [(50, 790, 1270, 2868)],
      top=y + 80, width=1105, radius=46, bleed_last=True)
save(c, "07-switch.png")

# ── 8 · DOCTOR ──────────────────────────────────────────────────────────────
c, d = frame(MINT, "#F2FAF4")
headline(d, "Years of it, in one file", "Take it to\nyour doctor", 165,
         sans_color="#3B6647", serif_color=INK, sans_size=66, serif_size=128)
stack(c, "S8_Export.png",
      [(50, 880, 1270, 1180),      # Take your data with you
       (50, 1180, 1270, 2868)],    # range, format, options — running off
      top=620, width=1105, gap=64, angles=[1.2, 0], radius=46, bleed_last=True)
save(c, "08-doctor.png")

print("\ndone")
