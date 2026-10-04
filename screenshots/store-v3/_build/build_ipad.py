#!/usr/bin/env python3
"""Caelyn's eight iPad 13" frames (2064x2752). Same story and same voice as the
phone; the canvas is far squarer, so the type breathes and the panels are wider
rather than taller.

Two shapes of source: full-page screens hold content in a centred readable
column at roughly x 350..1715, and sheets are a 1160x1268 form sheet at
x 452..1612, y 716..1984.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import compose as C

C.W, C.H = 2064, 2752
C.SRC = Path(__file__).parent.parent / "_sources" / "ipad"
C.OUT = Path(__file__).parent.parent / "ipad-13"

from compose import (frame, headline, pills, note, stack, cutout, save,
                     PLUM, INK, CREAM, WHITE)

ROSE  = "#F6C6D1"
MINT  = "#C2E0CA"
LILAC = "#D8CDF6"
SAND  = "#EFD2B2"
SHELL = "#FADCE1"

PW = 1700
COL0, COL1 = 350, 1715        # the readable column on full-page screens
SX0, SY0, SX1, SY1 = 452, 716, 1612, 1984   # a form sheet

# ── 1 · KNOW ────────────────────────────────────────────────────────────────
c, d = frame(ROSE, "#FFF4F1")
y = headline(d, "Always know", "where you are", 230,
             sans_color="#8A4F61", serif_color=INK, sans_size=118, serif_size=206)
y = pills(c, d, ["Private on device", "No account"], y + 40, fg=PLUM, bg=WHITE, size=56)
stack(c, "S1_Home.png", [(COL0, 300, COL1, 2752)], top=y + 90, width=PW,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "01-know.png")

# ── 2 · IS THIS NORMAL ──────────────────────────────────────────────────────
c, d = frame(MINT, "#F1FAF3")
y = headline(d, "The question nobody answers", "Is this normal?", 230,
             sans_color="#3B6647", serif_color=INK, sans_size=94, serif_size=196)
stack(c, "S2_PhaseGuide.png", [(SX0, SY0, SX1, SY1)], top=y + 100, width=PW,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "02-normal.png")

# ── 3 · PRIVACY ─────────────────────────────────────────────────────────────
c, d = frame(LILAC, "#F6F2FF")
y = headline(d, "No server. No account. No exceptions.", "It never leaves\nyour iPad", 225,
             sans_color="#4E4170", serif_color=INK, sans_size=82, serif_size=174)
y = pills(c, d, ["No ads", "No trackers", "Nothing sold"], y + 34, fg=PLUM, bg=WHITE, size=52)
stack(c, "S3_Privacy.png", [(40, 560, 2024, 2752)], top=y + 90, width=1880,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1990)
save(c, "03-private.png")

# ── 4 · PATTERNS ────────────────────────────────────────────────────────────
c, d = frame(SAND, "#FFF6EC")
y = headline(d, "Your numbers,", "not the textbook's", 230,
             sans_color="#80592E", serif_color=INK, sans_size=108, serif_size=174)
stack(c, "S4_Insights.png", [(COL0, 240, COL1, 2752)], top=y + 100, width=PW,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "04-patterns.png")

# ── 5 · LOG ─────────────────────────────────────────────────────────────────
c, d = frame(SHELL, "#FFF4F2")
y = headline(d, "However the day went,", "log how you feel", 230,
             sans_color="#96526A", serif_color=INK, sans_size=104, serif_size=184)
stack(c, "S6b_LoggedDaySymptoms.png", [(SX0, SY0, SX1, SY1)], top=y + 100,
      width=PW, radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "05-log.png")

# ── 6 · CALENDAR ────────────────────────────────────────────────────────────
c, d = frame("#F9CFD7", "#FFF5F2")
y = headline(d, "Every cycle,", "at a glance", 230,
             sans_color="#9B5668", serif_color=INK, sans_size=108, serif_size=196)
stack(c, "S5_Calendar.png", [(COL0, 240, COL1, 2752)], top=y + 100, width=PW,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "06-calendar.png")

# ── 7 · SWITCH ──────────────────────────────────────────────────────────────
c, d = frame(LILAC, "#F7F3FF")
y = headline(d, "Leaving another app?", "Bring it with you", 230,
             sans_color="#4E4170", serif_color=INK, sans_size=104, serif_size=180)
y = note(d, "Nothing you have already logged will change.", y + 32, "#4E4170", size=54)
stack(c, "S7_BringHistory.png", [(SX0, SY0, SX1, SY1)], top=y + 90, width=PW,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "07-switch.png")

# ── 8 · DOCTOR ──────────────────────────────────────────────────────────────
c, d = frame(MINT, "#F2FAF4")
y = headline(d, "Years of it, in one file", "Take it to\nyour doctor", 225,
             sans_color="#3B6647", serif_color=INK, sans_size=94, serif_size=180)
stack(c, "S8_Export.png", [(SX0, SY0, SX1, SY1)], top=y + 90, width=PW,
      radius=70, blur=44, bleed_last=True, max_bleed_width=1960)
save(c, "08-doctor.png")

print("\ndone")
