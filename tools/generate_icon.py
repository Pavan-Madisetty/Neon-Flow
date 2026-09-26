#!/usr/bin/env python3
"""Draws the launcher icon (neon pipes on dark) and writes Android mipmaps.
Requires Pillow. Run automatically by tools/setup_android.sh when available."""
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    print("Pillow not installed; keeping the default Flutter icon.")
    sys.exit(0)

ROOT = os.path.join(os.path.dirname(__file__), "..")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
S = 1024

COLORS = [(255, 59, 59), (47, 139, 255), (57, 211, 83), (255, 210, 31)]


def draw_icon():
    bg = Image.new("RGB", (S, S), (11, 16, 48))
    d = ImageDraw.Draw(bg)
    for y in range(S):  # vertical gradient
        t = y / S
        d.line([(0, y), (S, y)], fill=(int(11 * (1 - t) + 5 * t), int(16 * (1 - t) + 7 * t), int(48 * (1 - t) + 15 * t)))

    layers = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(layers)
    w = 92
    # (points, colour) laid out on a 4x4 board inside the safe zone
    cell = 190
    ox = oy = (S - cell * 4) // 2

    def pt(r, c):
        return (ox + c * cell + cell // 2, oy + r * cell + cell // 2)

    paths = [
        ([(0, 0), (0, 1), (0, 2)], COLORS[0]),
        ([(0, 3), (1, 3), (1, 2), (1, 1)], COLORS[1]),
        ([(1, 0), (2, 0), (3, 0), (3, 1)], COLORS[2]),
        ([(2, 1), (2, 2), (2, 3), (3, 3)], COLORS[3]),
    ]
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for cells, col in paths:
        pts = [pt(*c) for c in cells]
        for (a, b) in zip(pts, pts[1:]):
            gd.line([a, b], fill=col + (200,), width=w + 46)
        for p in (pts[0], pts[-1]):
            gd.ellipse([p[0] - 78, p[1] - 78, p[0] + 78, p[1] + 78], fill=col + (200,))
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    for cells, col in paths:
        pts = [pt(*c) for c in cells]
        for (a, b) in zip(pts, pts[1:]):
            g.line([a, b], fill=col + (255,), width=w)
        for p in pts:
            g.ellipse([p[0] - w // 2, p[1] - w // 2, p[0] + w // 2, p[1] + w // 2], fill=col + (255,))
        for p in (pts[0], pts[-1]):
            g.ellipse([p[0] - 66, p[1] - 66, p[0] + 66, p[1] + 66], fill=col + (255,))
            g.ellipse([p[0] - 34, p[1] - 44, p[0] - 8, p[1] - 18], fill=(255, 255, 255, 150))
    bg = bg.convert("RGBA")
    bg.alpha_composite(glow)
    bg.alpha_composite(layers)
    return bg.convert("RGB")


def main():
    if not os.path.isdir(RES):
        print("android/ not generated yet; run flutter create first.")
        return
    icon = draw_icon()
    icon.save(os.path.join(ROOT, "assets", "icon_1024.png"))
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px in sizes.items():
        out = os.path.join(RES, f"mipmap-{name}")
        os.makedirs(out, exist_ok=True)
        icon.resize((px, px), Image.LANCZOS).save(os.path.join(out, "ic_launcher.png"))
    print("Launcher icons written.")


if __name__ == "__main__":
    main()
