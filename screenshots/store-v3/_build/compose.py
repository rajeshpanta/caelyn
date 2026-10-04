#!/usr/bin/env python3
"""
Caelyn App Store frames, v3.

Why a third pass
----------------
v1 was a whole phone on a purple radial gradient with four-point sparkles — the
house style of every AI image generator, and illegible at thumbnail size.

v2 fixed the legibility: flat grounds, heavy SF, the interface zoomed and bled
off the bottom edge. It is a competent modern app-store set. It is also cold.
Deep plum grounds and a black grotesque read *technical* — a developer tool, a
security product — and this app is for women choosing something to keep the most
intimate record they own. "Trustworthy" and "severe" are not the same feeling.

So v3 went back to what the category actually ships, across twelve apps rather
than three:

  Moody Month  soft sage-mint wash, light serif headline, VOGUE / Women's Health
               / ELLE logos, device floating under a gentle shadow. Calm, premium.
  Clue         editorial colour blocks, a bold sans line answered by an italic
               serif one — "Know your / *next period*". Trust pills at the foot.
  Flo          pale lavender, the payload of the headline sitting in a rounded
               highlight, warm illustrated chips, UI floating rather than bled.
  Natural      real photography, warm beige, "#1 FDA Cleared" worn as a badge.
  Ovia         cream and lavender, serif headline, enormous whitespace.
  Stardust     press logos and "2 million monthly users" above the fold.
  Period Cal.  "Trusted by 300M women" as the FIRST thing on the FIRST frame.

Two things nearly all of them do that v2 did not:

1. **An elegant serif.** Almost every frame that feels premium in this category
   pairs a sans with a serif — usually italic, usually carrying the emotional
   half of the sentence. It is the single biggest difference between "an app"
   and "an app I would want".

2. **Trust worn on the surface.** User counts, press logos, FDA clearance, star
   ratings. Caelyn cannot claim any of those honestly — it is new and it has no
   press. But it can say the one thing none of them can, which is that nothing
   leaves the phone, and it can say it as a badge rather than as body copy.

The serif here is New York — Apple's own, drawn to sit beside SF. It reads as
part of iOS rather than as a font someone imported, which matters when the whole
promise is that this app belongs on your phone and nowhere else.

The palette is Caelyn's own, used the way the app uses it: light grounds, plum
reserved for ink and accent. v2 inverted that and the result looked like a
different product.
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

W, H = 1320, 2868

SRC = Path(__file__).parent.parent / "_sources" / "iphone"
OUT = Path(__file__).parent.parent / "iphone-6.9"

# Caelyn's real light-mode palette, from Theme/Color+Caelyn.swift.
PLUM     = "#6F3D74"
INK      = "#2F1B32"
CREAM    = "#FFF8F3"
WHITE    = "#FFFFFF"
BLUSH    = "#FBE4E7"
LAVENDER = "#EEE7FF"
SAGE     = "#DCEBDD"
WARMSAND = "#F4E2D1"
SOFTROSE = "#EFA7B2"

SANS       = "/System/Library/Fonts/SFNS.ttf"
SANS_BLACK = "/Users/smile/Library/Fonts/SF-Pro-Display-Black.otf"
SERIF      = "/System/Library/Fonts/NewYork.ttf"
SERIF_IT   = "/System/Library/Fonts/NewYorkItalic.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def text_w(draw, s, f):
    return draw.textbbox((0, 0), s, font=f)[2]


def hexf(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def wash(top, bottom, warp=1.0):
    """A soft vertical wash.

    Two stops, low contrast, no radial glow and no centre hotspot — the radial
    purple bloom is the thing that read as machine-made, not gradients as such.
    Moody Month and Flo both ground their frames in exactly this kind of quiet
    wash.
    """
    a, b = hexf(top), hexf(bottom)
    base = Image.new("RGB", (1, H))
    px = base.load()
    for y in range(H):
        t = (y / (H - 1)) ** warp
        px[0, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return base.resize((W, H), Image.BILINEAR).convert("RGBA")


def frame(top, bottom=None, warp=1.0):
    c = wash(top, bottom or CREAM, warp)
    return c, ImageDraw.Draw(c)


def headline(draw, sans_line, serif_line, y, sans_color, serif_color,
             sans_size=84, serif_size=132, gap=14, center=True, tracking=0):
    """
    A sans line answering a serif one.

    The sans states the fact and the serif carries the feeling — Clue's "Know
    your" / "*next period*". At a glance the serif is what makes the frame look
    considered rather than assembled.
    """
    sf = font(SANS, sans_size)
    rf = font(SERIF_IT, serif_size)

    if sans_line:
        w = text_w(draw, sans_line, sf)
        x = (W - w) // 2 if center else 110
        draw.text((x, y), sans_line, font=sf, fill=sans_color)
        y += int(sans_size * 1.12) + gap

    for line in serif_line.split("\n"):
        w = text_w(draw, line, rf)
        x = (W - w) // 2 if center else 110
        draw.text((x, y), line, font=rf, fill=serif_color)
        y += int(serif_size * 1.02)
    return y


def pills(canvas, draw, items, y, fg, bg, size=40):
    """Trust worn on the surface, the way Clue runs them under frame one."""
    f = font(SANS, size)
    gap, pad, hgt = 22, 76, int(size * 2.25)
    widths = [text_w(draw, t, f) + pad for t in items]
    total = sum(widths) + gap * (len(items) - 1)
    x = (W - total) // 2
    for t, w in zip(items, widths):
        draw.rounded_rectangle([x, y, x + w, y + hgt], radius=hgt // 2, fill=bg)
        draw.text((x + pad // 2, y + (hgt - size) // 2 - 4), t, font=f, fill=fg)
        x += w + gap
    return y + hgt


def panel(canvas, src_name, crop, top, width=1140, radius=62, bleed=True,
          shadow=True):
    """
    The interface, floating under a warm shadow.

    v2 bled every panel hard off the bottom edge, which is Flo's move and reads
    as energetic. Softened here: the panel still runs past the bottom so the
    screen feels like a window onto something continuing, but it is inset from
    the sides with real margin and sits under a diffuse warm shadow rather than
    meeting the edge. That is the Moody / Natural Cycles register — the frame
    has room to breathe, which is most of what makes a layout feel calm.
    """
    img = Image.open(SRC / src_name).convert("RGBA").crop(crop)
    scale = width / img.width
    tw, th = int(img.width * scale), int(img.height * scale)
    img = img.resize((tw, th), Image.LANCZOS)

    if bleed:
        th = min(th, H - top + radius)
        img = img.crop((0, 0, tw, th))

    mask = Image.new("L", (tw, th), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, tw - 1, th - 1 if not bleed else th + radius], radius=radius, fill=255)
    img.putalpha(mask)

    x = (W - tw) // 2
    if shadow:
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle(
            [x + 10, top + 26, x + tw - 10, top + th + 26],
            radius=radius, fill=(120, 70, 100, 62))
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(44)))
    canvas.alpha_composite(img, (x, top))
    return top + th


def note(draw, text, y, color, size=40, center=True):
    """One quiet line under a headline, where a frame needs a beat of detail."""
    f = font(SANS, size)
    for line in text.split("\n"):
        w = text_w(draw, line, f)
        x = (W - w) // 2 if center else 110
        draw.text((x, y), line, font=f, fill=color)
        y += int(size * 1.32)
    return y


def save(canvas, name):
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT / name, "PNG", optimize=True)
    print(f"  wrote {name}")


# ─────────────────────────────────────────────────────────────────────────────
# Layered cut-outs
#
# The single flat panel is the thing that still read "simple" next to the
# category. In the App Store's search grid you see three frames side by side at
# roughly 250px, and what survives that is DEPTH and CONTRAST — Lively's floating
# angled cards, Clue's cut-out fragments over photography, Flo's layered chips.
# One rectangle of UI on a pale wash does not.
#
# So instead of showing a screen, these frames show PIECES of it: a card lifted
# out, rounded, tilted a degree or two and dropped on its own shadow, with a
# second smaller piece overlapping it. It reads as a product with dimension
# rather than a screenshot with a caption, and the pieces chosen are the ones
# carrying the big legible numbers.
# ─────────────────────────────────────────────────────────────────────────────

def cutout(canvas, src_name, crop, width, center, angle=0.0, radius=46,
           shadow=True, shadow_alpha=74, blur=34, lift=18, border=None):
    """Lift one card out of a screenshot and float it.

    `center` is where the finished piece lands, as (x, y) of its middle.
    `angle` is degrees counter-clockwise; one or two is plenty — more looks like
    a template, which is the trap this whole set keeps circling.
    """
    img = Image.open(SRC / src_name).convert("RGBA").crop(crop)
    scale = width / img.width
    tw, th = int(img.width * scale), int(img.height * scale)
    img = img.resize((tw, th), Image.LANCZOS)

    mask = Image.new("L", (tw, th), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tw - 1, th - 1], radius=radius, fill=255)
    img.putalpha(mask)

    if border:
        ring = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        ImageDraw.Draw(ring).rounded_rectangle([0, 0, tw - 1, th - 1], radius=radius,
                                               outline=border, width=3)
        img.alpha_composite(ring)

    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC, expand=True)

    pw, ph = img.size
    x, y = int(center[0] - pw / 2), int(center[1] - ph / 2)

    if shadow:
        sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        alpha = img.split()[3].point(lambda a: int(a * shadow_alpha / 255))
        solid = Image.new("RGBA", img.size, (96, 52, 80, 255))
        solid.putalpha(alpha)
        sh.alpha_composite(solid, (x, y + lift))
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))

    canvas.alpha_composite(img, (x, y))
    return (x, y, x + pw, y + ph)


def badge(canvas, draw, lines, center, r=132, fill="#FFFFFF", ink=None,
          accent=None, size=34):
    """A round seal, the way Flo wears FSA/HSA and Lively wears its star rating.

    Caelyn cannot honestly claim a user count, a press logo or FDA clearance, so
    the seal carries the one thing none of its rivals can say at all.
    """
    ink = ink or INK
    accent = accent or PLUM
    cx, cy = center
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 14, cx + r, cy + r + 14],
                               fill=(96, 52, 80, 80))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(26)))
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    draw.ellipse([cx - r + 13, cy - r + 13, cx + r - 13, cy + r - 13],
                 outline=accent, width=3)
    f = font(SANS, size)
    total = len(lines) * int(size * 1.3)
    y = cy - total // 2
    for i, line in enumerate(lines):
        fl = font(SANS_BLACK, int(size * 1.25)) if i == 0 else f
        w = text_w(draw, line, fl)
        draw.text((cx - w // 2, y), line, font=fl, fill=accent if i == 0 else ink)
        y += int(size * 1.3)


def stack(canvas, src_name, pieces, top, width, gap=52, angles=None,
          radius=46, blur=34, x_center=None, bleed_last=False,
          max_bleed_width=1248, center_in=None):
    """Lay cut-outs down the frame without any of them running off the bottom.

    Hand-placing each piece by eye is how the last pass ended up with cards
    clipped at the canvas edge and two copies of the same list. This takes the
    crops, works out their scaled heights and stacks them, so the only thing to
    choose is where the run starts.

    Returns the y the run ended at, or None if a piece would not have fitted —
    which is a bug in the frame, not something to silently crop.
    """
    angles = angles or [0] * len(pieces)
    cx = x_center or W // 2

    # Where a source simply does not have the height to reach the bottom edge,
    # bleeding it would mean zooming past the point where the text survives. Far
    # better to let the run sit centred in the space it has: whitespace above AND
    # below reads as composition, whereas whitespace only below reads as a
    # mistake. Ovia and Moody both leave this much air on purpose.
    if center_in:
        total = sum(int((c[3] - c[1]) * (width / (c[2] - c[0]))) for c in pieces)
        total += gap * (len(pieces) - 1)
        y0, y1 = center_in
        top = y0 + max(0, (y1 - y0 - total) // 2)

    y = top
    last = len(pieces) - 1
    for i, (crop, ang) in enumerate(zip(pieces, angles)):
        ch = crop[3] - crop[1]
        cw = crop[2] - crop[0]
        h = int(ch * (width / cw))

        # The final piece runs off the bottom edge rather than stopping short.
        # Floating every card left the lower third of each frame empty, which
        # reads as unfinished; letting the last one continue past the edge says
        # the screen carries on, which is the Flo / Clue move and is also what
        # stops a frame looking like three stickers on a background.
        if bleed_last and i == last:
            avail = H - y
            img = Image.open(SRC / src_name).convert("RGBA").crop(crop)
            # Reach the bottom edge by zooming, never by cropping sideways:
            # trimming the width to fit chopped the ends off every line, which is
            # far worse than a little bare ground. The zoom is capped at a width
            # that still leaves a margin, so a frame whose source simply runs out
            # ends slightly short rather than losing its text.
            scale = max(width / img.width, avail / img.height)
            scale = min(scale, max_bleed_width / img.width)
            tw, th = int(img.width * scale), int(img.height * scale)
            img = img.resize((tw, th), Image.LANCZOS)
            th = min(th, avail)
            img = img.crop((0, 0, tw, th))
            mask = Image.new("L", (tw, th), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, tw - 1, th + radius],
                                                   radius=radius, fill=255)
            img.putalpha(mask)
            x = cx - tw // 2
            sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            ImageDraw.Draw(sh).rounded_rectangle(
                [x, y + 20, x + tw, y + th + 20], radius=radius,
                fill=(96, 52, 80, 70))
            canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
            canvas.alpha_composite(img, (x, y))
            return H

        if y + h > H - 20:
            print(f"    ! {src_name} piece {crop} would overflow "
                  f"({y + h} > {H}); shorten the run")
            return None
        cutout(canvas, src_name, crop, width, (cx, y + h // 2), angle=ang,
               radius=radius, blur=blur)
        y += h + gap
    return y
