#!/usr/bin/env python3
"""Compose a Caelyn App Store screenshot.

Design language, shared with the App Preview video:
  - a soft plum-to-rose gradient rather than a flat block of colour
  - blurred bokeh blooms and hand-placed sparkles for warmth
  - SF Pro Rounded (the app's own face) — Black for the verb, Bold for the line
    under it, so the type feels like the product rather than a stock template
  - the phone floats with a real drop shadow and bleeds off the bottom edge
"""
import argparse
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1290, 2796
FONT = "/System/Library/Fonts/SFNSRounded.ttf"

# Palette — plum through rose, taken from Caelyn's own tokens and warmed.
TOP = (78, 33, 88)
MID = (140, 60, 106)
BOT = (206, 116, 150)
CREAM = (255, 228, 238)


def font(size, weight="Black"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient():
    """Vertical three-stop gradient, drawn per row."""
    g = Image.new("RGB", (1, H))
    d = ImageDraw.Draw(g)
    for y in range(H):
        t = y / (H - 1)
        if t < 0.55:
            u = t / 0.55
            c = tuple(round(TOP[i] + (MID[i] - TOP[i]) * u) for i in range(3))
        else:
            u = (t - 0.55) / 0.45
            c = tuple(round(MID[i] + (BOT[i] - MID[i]) * u) for i in range(3))
        d.point((0, y), fill=c)
    return g.resize((W, H), Image.BILINEAR)


def blooms(img):
    """Soft out-of-focus colour blooms so the ground isn't a flat wash."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for cx, cy, r, col, a in [
        (int(W * 0.18), int(H * 0.10), 460, (255, 170, 205), 70),
        (int(W * 0.92), int(H * 0.22), 520, (186, 140, 235), 60),
        (int(W * 0.05), int(H * 0.62), 560, (255, 150, 180), 42),
        (int(W * 0.98), int(H * 0.78), 600, (255, 200, 220), 38),
    ]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(180))
    img.alpha_composite(layer)


def star(d, cx, cy, r, alpha):
    """A four-point sparkle with concave sides — softer than a plain star."""
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    d.polygon(pts, fill=(255, 245, 250, alpha))


def sparkles(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Kept clear of the headline block and the phone face.
    for x, y, r, a in [
        (118, 300, 26, 200), (1168, 250, 20, 170), (196, 690, 15, 140),
        (1108, 640, 30, 190), (80, 980, 18, 120), (1216, 980, 14, 130),
        (1000, 132, 16, 150), (250, 140, 13, 120),
        (60, 1700, 20, 90), (1230, 1560, 16, 90), (44, 2180, 24, 80),
        (1246, 2260, 18, 80),
    ]:
        star(d, x, y, r, a)
    img.alpha_composite(layer)


def fit(text, weight, target_w, start, min_size=40):
    """Largest size at which the line fits the safe width."""
    size = start
    while size > min_size:
        f = font(size, weight)
        if ImageDraw.Draw(Image.new("RGB", (10, 10))).textlength(text, font=f) <= target_w:
            return f
        size -= 4
    return font(min_size, weight)


def wrap(text, f, max_w):
    d = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        t = (cur + " " + w_).strip()
        if d.textlength(t, font=f) <= max_w or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w_
    if cur:
        lines.append(cur)
    return lines


def phone(img, shot_path, top):
    """Screenshot in a dark bezel, floating, bleeding off the bottom."""
    shot = Image.open(shot_path).convert("RGB")
    target_w = 880
    scale = target_w / shot.width
    shot = shot.resize((target_w, round(shot.height * scale)), Image.LANCZOS)

    radius, bez = 58, 13
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width, shot.height], radius, fill=255)
    shot.putalpha(mask)

    bw, bh = shot.width + bez * 2, shot.height + bez * 2
    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, bw, bh], radius + bez, fill=(22, 12, 26, 255))
    body.alpha_composite(shot, (bez, bez))

    x = (W - bw) // 2
    y = int(top)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 14, y + 30, x + bw + 14, y + bh + 30], radius + bez, fill=(30, 8, 26, 150)
    )
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(38)))
    img.alpha_composite(body, (x, y))


def compose(verb, desc, shot_path, out):
    img = gradient().convert("RGBA")
    blooms(img)
    sparkles(img)

    safe = int(W * 0.80)
    d = ImageDraw.Draw(img)

    fv = fit(verb.upper(), "Black", safe, 250)
    fd = fit("MMMMMMMMMMMMMMMMMM", "Bold", safe, 108)  # uniform size across the set
    dlines = wrap(desc.upper(), fd, safe)

    y = 132
    tw = d.textlength(verb.upper(), font=fv)
    # A whisper of shadow keeps white type crisp over the lighter parts.
    d.text(((W - tw) / 2 + 3, y + 4), verb.upper(), font=fv, fill=(60, 20, 60, 90))
    d.text(((W - tw) / 2, y), verb.upper(), font=fv, fill=(255, 255, 255, 255))
    y += fv.size * 1.02

    for line in dlines:
        lw = d.textlength(line, font=fd)
        d.text(((W - lw) / 2 + 2, y + 3), line, font=fd, fill=(60, 20, 60, 70))
        d.text(((W - lw) / 2, y), line, font=fd, fill=CREAM + (255,))
        y += fd.size * 1.12

    # A steady 96px of air under the type, whatever size the verb landed at.
    rule_y = y + 46
    for i, (dx, r, a) in enumerate([(-96, 11, 150), (0, 18, 220), (96, 11, 150)]):
        star(d, W / 2 + dx, rule_y, r, a)
    y = rule_y + 40

    phone(img, shot_path, y + 96)
    img.convert("RGB").save(out)
    print(f"✓ {out}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--verb", required=True)
    p.add_argument("--desc", required=True)
    p.add_argument("--screenshot", required=True)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    compose(a.verb, a.desc, a.screenshot, a.output)
