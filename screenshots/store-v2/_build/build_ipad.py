#!/usr/bin/env python3
"""Caelyn's eight iPad 13" App Store frames — same story, same grammar, iPad canvas.

The iPad slot is 2064x2752: a much squarer frame than the phone's 1320x2868, so
the headline gets more room and the UI slice is wider rather than taller. Two
shapes of source exist on iPad and they crop differently:

  * full-page screens — the app constrains content to a centred readable column
    at roughly x 350..1715, so that column is what gets cropped; the empty
    side margins are the frame's ground instead.
  * sheets (phase guide, import, export, day detail) — iPad presents them as a
    1160x1300 form sheet at x 452..1612, y 716..2016. Scaled to 1760 wide that
    is 1972 tall, which bleeds off the bottom edge from y 780 almost exactly.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import compose as C

C.W, C.H = 2064, 2752
C.SCALE = 1.55
C.SRC = Path(__file__).parent.parent / "_sources" / "ipad"
C.OUT = Path(__file__).parent.parent / "ipad-13"

from compose import (frame, headline, pills, place, breakout, save,
                        PLUM, INK, CREAM, WHITE, BLUSH, LAVENDER, SAGE, WARMSAND)

FULL = 2752
COL  = (350, None, 1715, FULL)     # the readable column on full-page screens
SHEET_X0, SHEET_X1 = 452, 1612
# The form sheet's own bottom corners are rounded, so cropping all the way to its
# last row (2016) drags two grey wedges of the dimmed page in with it. 1984 is the
# last row that is still full width.
SHEET_Y0, SHEET_Y1 = 716, 1984

def col(y0):
    return (COL[0], y0, COL[2], FULL)

def sheet():
    return (SHEET_X0, SHEET_Y0, SHEET_X1, SHEET_Y1)


def sheet_width(top):
    """The scale at which a sheet placed at `top` reaches the bottom edge exactly.

    A sheet is a fixed 1160x1268 slice, so unlike a full-page screen it cannot
    just be cropped longer to make it bleed — it has to be scaled to fit the gap
    the headline leaves behind.
    """
    return int((FULL - top) / (SHEET_Y1 - SHEET_Y0) * (SHEET_X1 - SHEET_X0))

SLICE_W = 1760

# 1 — KNOW
c, d = frame(PLUM)
y = headline(d, "Always know", "where you are", 230,
             ink="#E3C6E7", accent=WHITE, size=200, light_size=126)
y = pills(c, d, ["Private on device", "No account needed"], y + 46,
          fg=PLUM, bg="#F7EBF9")
place(c, "S1_Home.png", col(300), y + 110, width=SLICE_W, bleed=True, radius=64)
save(c, "01-know.png")

# 2 — IS THIS NORMAL
c, d = frame(SAGE)
y = headline(d, "The question nobody answers", "Is this normal?", 240,
             ink="#4C6E52", accent=INK, size=190, light_size=104)
place(c, "S2_PhaseGuide.png", sheet(), y + 120, width=sheet_width(y + 120),
      bleed=True, radius=64)
save(c, "02-normal.png")

# 3 — PRIVACY
#
# The phone frame overlays a white breakout card here, because at 1320pt the
# page's own body copy is unreadable. The iPad has no such problem: the privacy
# page is full-width, so it is cropped edge to edge at close to 1:1 and simply
# allowed to speak for itself. Adding the breakout on top would have repeated
# the page's own heading back at the reader word for word.
c, d = frame(INK)
y = headline(d, "No server. No account. No exceptions.", "It never leaves\nyour iPad", 230,
             ink="#C6A2CB", accent=WHITE, size=180, light_size=92)
place(c, "S3_Privacy.png", (40, 280, 2024, FULL), y + 130, width=1900,
      bleed=True, radius=64)
save(c, "03-private.png")

# 4 — PATTERNS
c, d = frame(LAVENDER)
y = headline(d, "Your numbers,", "not the textbook's", 240,
             ink=PLUM, accent=INK, size=168, light_size=118)
place(c, "S4_Insights.png", col(240), y + 120, width=SLICE_W, bleed=True, radius=64)
save(c, "04-patterns.png")

# 5 — LOG
c, d = frame(BLUSH)
y = headline(d, "However the day went,", "log how you feel", 240,
             ink="#B4677A", accent=INK, size=180, light_size=114)
place(c, "S6b_LoggedDaySymptoms.png", sheet(), y + 120, width=sheet_width(y + 120),
      bleed=True, radius=64)
save(c, "05-log.png")

# 6 — CALENDAR
c, d = frame(CREAM)
y = headline(d, "Every cycle,", "at a glance", 240,
             ink="#D98496", accent=INK, size=190, light_size=124)
place(c, "S5_Calendar.png", col(240), y + 120, width=SLICE_W, bleed=True, radius=64)
save(c, "06-calendar.png")

# 7 — SWITCH
c, d = frame(WARMSAND)
y = headline(d, "Leaving another app?", "Bring it with you", 240,
             ink="#9A6B3E", accent=INK, size=176, light_size=114)
place(c, "S7_BringHistory.png", sheet(), y + 120, width=sheet_width(y + 120),
      bleed=True, radius=64)
save(c, "07-switch.png")

# 8 — DOCTOR
c, d = frame(PLUM)
y = headline(d, "Years of it, in one file", "Take it to\nyour doctor", 230,
             ink="#E3C6E7", accent=WHITE, size=190, light_size=104)
place(c, "S8_Export.png", sheet(), y + 120, width=sheet_width(y + 120),
      bleed=True, radius=64)
save(c, "08-doctor.png")

print("\ndone")
