#!/usr/bin/env python3
"""
Caelyn App Store frames, v2.

What changed from v1 and why
----------------------------
v1 put a whole phone on a purple radial gradient scattered with four-point
sparkles. That reads as a template: the gradient-plus-sparkle look is the house
style of every AI image generator and every Canva app-store kit, and showing a
whole screen shrunk to fit means the UI itself is illegible at the ~250px width
a shopper actually sees in search results.

Looking at what the category leaders actually ship:
  * Clue    — full-bleed photography, logo, mixed serif/sans headline, the UI
              reduced to ONE cut-out element, trust pills along the bottom.
  * Flo     — flat lavender ground, "Predict your" light + "next period" heavy
              inside a highlight pill, UI zoomed ~2x and bled off the bottom.
  * Natural — flat ground, heavy black headline, a white "breakout" card
    Cycles    overlapping the device so one sentence escapes the frame.

The shared grammar is: flat or photographic ground, one typographic emphasis,
the interface zoomed in and cropped rather than shrunk down, and the frame
bleeding off the bottom edge instead of floating.

This composer implements that grammar with Caelyn's own palette and SF (the
typeface the app itself is drawn in), so the store page and the product look
like the same thing.
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

W, H = 1320, 2868

# Set to 1.0 for the iPhone canvas; the iPad build raises it so the furniture
# (pills, breakout cards) scales with the wider frame instead of shrinking.
SCALE = 1.0

# Each build script points these at its own idiom before composing.
SRC = Path(__file__).parent.parent / "_sources" / "iphone"
OUT = Path(__file__).parent.parent / "iphone-6.9"

# Caelyn's real light-mode palette, lifted from Theme/Color+Caelyn.swift.
PLUM       = "#6F3D74"
INK        = "#2F1B32"
CREAM      = "#FFF8F3"
WHITE      = "#FFFFFF"
BLUSH      = "#FBE4E7"
LAVENDER   = "#EEE7FF"
SAGE       = "#DCEBDD"
WARMSAND   = "#F4E2D1"
SOFTROSE   = "#EFA7B2"

BLACK_F = "/Users/smile/Library/Fonts/SF-Pro-Display-Black.otf"
SANS_F  = "/System/Library/Fonts/SFNS.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def text_w(draw, s, f):
    return draw.textbbox((0, 0), s, font=f)[2]


def rounded(img, radius):
    """Round the corners of an RGBA image."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1],
                                           radius=radius, fill=255)
    out = img.copy().convert("RGBA")
    out.putalpha(mask)
    return out


def shadow(canvas, box, radius, blur=38, alpha=58, offset=(0, 16)):
    """A soft drop shadow under a rounded box — depth without a fake 3-D frame."""
    from PIL import ImageFilter
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]],
        radius=radius, fill=(40, 20, 44, alpha))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def headline(draw, light, heavy, y, ink, accent=None, size=118, light_size=None,
             center=True, pill=None):
    """
    Two-tone headline: a lighter setup line, then the payload in SF Pro Black.

    The contrast is the whole point — a single weight at a single size is what
    made v1 read as a template. `pill` draws Flo's highlight block behind the
    heavy line.
    """
    accent = accent or ink
    lf = font(SANS_F, light_size or int(size * 0.74))
    hf = font(BLACK_F, size)

    if light:
        w = text_w(draw, light, lf)
        x = (W - w) // 2 if center else 96
        draw.text((x, y), light, font=lf, fill=ink)
        y += int((light_size or size * 0.74) * 1.18)

    for line in heavy.split("\n"):
        w = text_w(draw, line, hf)
        x = (W - w) // 2 if center else 96
        if pill:
            pad_x, pad_y = 38, 20
            draw.rounded_rectangle([x - pad_x, y - pad_y + 10, x + w + pad_x, y + size + pad_y - 14],
                                   radius=34, fill=pill)
        draw.text((x, y), line, font=hf, fill=accent)
        y += int(size * 1.08)
    return y


def pills(canvas, draw, items, y, fg, bg):
    """Trust badges. Clue runs these along the bottom of frame 1; they carry the
    two things a privacy-first tracker can say that rivals cannot."""
    s = SCALE
    f = font(SANS_F, int(42 * s))
    gap = int(26 * s)
    pad = int(86 * s)
    hgt = int(92 * s)
    widths = [text_w(draw, t, f) + pad for t in items]
    total = sum(widths) + gap * (len(items) - 1)
    x = (W - total) // 2
    for t, w in zip(items, widths):
        draw.rounded_rectangle([x, y, x + w, y + hgt], radius=hgt // 2, fill=bg)
        draw.text((x + pad // 2, y + int(22 * s)), t, font=f, fill=fg)
        x += w + gap
    return y + hgt


def place(canvas, src_name, crop, top, width=1180, radius=54, shadow_on=True,
          bleed=False):
    """
    Drop a slice of the real UI onto the canvas.

    `crop` is (x0, y0, x1, y1) in the 1320x2868 source; the slice is scaled to
    `width` and placed at `top`.

    With `bleed=True` the panel runs off the bottom edge of the frame and only its
    top corners are rounded. That is the single composition move that separates the
    category leaders from a template: Flo, Clue and Natural Cycles all let the
    interface run out of frame, which reads as a window onto a real product rather
    than a phone floating in space.
    """
    from PIL import ImageFilter
    img = Image.open(SRC / src_name).convert("RGBA").crop(crop)
    scale = width / img.width
    tw, th = int(img.width * scale), int(img.height * scale)
    img = img.resize((tw, th), Image.LANCZOS)

    if bleed:
        th = min(th, H - top)
        img = img.crop((0, 0, tw, th))
        mask = Image.new("L", (tw, th), 0)
        md = ImageDraw.Draw(mask)
        md.rounded_rectangle([0, 0, tw - 1, th + radius], radius=radius, fill=255)
        img.putalpha(mask)
    else:
        img = rounded(img, radius)

    x = (W - tw) // 2
    if shadow_on:
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle(
            [x, top + 16, x + tw, top + th + (radius if bleed else 0) + 16],
            radius=radius, fill=(40, 20, 44, 60))
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(38)))
    canvas.alpha_composite(img, (x, top))
    return top + th


def breakout(canvas, draw, title, body, y, w=1130, ink=INK, accent=PLUM):
    """
    A white card that overlaps the UI — Natural Cycles' move. One sentence gets to
    escape the interface and speak directly, which is what a shopper actually
    reads.
    """
    sc = SCALE
    f_t = font(BLACK_F, int(56 * sc))
    f_b = font(SANS_F, int(42 * sc))
    pad_x, line_h, title_gap = int(55 * sc), int(58 * sc), int(78 * sc)

    words, lines, cur = body.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if text_w(draw, t, f_b) > w - 2 * pad_x:
            lines.append(cur); cur = wd
        else:
            cur = t
    lines.append(cur)

    h = int(52 * sc) + title_gap + len(lines) * line_h + int(36 * sc)
    x = (W - w) // 2
    r = int(46 * sc)
    shadow(canvas, (x, y, x + w, y + h), r, blur=int(44 * sc), alpha=70,
           offset=(0, int(18 * sc)))
    draw.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=WHITE)
    draw.text((x + pad_x, y + int(48 * sc)), title, font=f_t, fill=accent)
    ty = y + int(48 * sc) + title_gap
    for ln in lines:
        draw.text((x + pad_x, ty), ln, font=f_b, fill=ink)
        ty += line_h
    return y + h


def frame(bg):
    c = Image.new("RGBA", (W, H), bg)
    return c, ImageDraw.Draw(c)


def save(canvas, name):
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT / name, "PNG", optimize=True)
    print(f"  wrote {name}")
