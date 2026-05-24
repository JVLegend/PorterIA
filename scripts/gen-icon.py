#!/usr/bin/env python3
"""
PorterIA macOS app icon generator.

Concept: Stylized "P" inside a Big Sur-style rounded squircle with a subtle
gradient evoking a network port / gateway. The P doubles as a doorway opening.

Generates the 10 sizes required by Apple's iconset spec and writes them to
/tmp/PorterIA.iconset/, ready for `iconutil -c icns`.

Usage:
    python3 scripts/gen-icon.py
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ICONSET_DIR = Path("/tmp/PorterIA.iconset")

# Brand palette: deep teal -> indigo gradient on the tile, white glyph.
# Reads as "network / port / trust" without screaming.
COLOR_TOP = (24, 110, 138)        # teal
COLOR_BOTTOM = (40, 56, 120)      # indigo
COLOR_GLYPH = (255, 255, 255)     # white
COLOR_GLYPH_SHADOW = (0, 0, 0, 60)

# Apple iconset sizes: (filename, pixel_size)
SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def rounded_squircle_mask(size: int, radius_ratio: float = 0.2237) -> Image.Image:
    """Big Sur-ish rounded square mask. Apple uses ~22.37% corner radius."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    r = int(size * radius_ratio)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=r, fill=255)
    return mask


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """Smooth vertical gradient from top to bottom color."""
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        grad.putpixel((0, y), (r, g, b))
    return grad.resize((size, size))


def draw_glyph_P(canvas: Image.Image, simplified: bool) -> None:
    """
    Draw a stylized "P" glyph that doubles as a doorway opening.

    The P is built from primitives (rounded rect stem + ring bowl) instead of a
    font, so it stays sharp at every size and avoids the "AI-generated mediocre"
    look that fonts inside icons often produce.

    `simplified=True` thickens strokes and drops fine details for small sizes.
    """
    size = canvas.size[0]
    draw = ImageDraw.Draw(canvas, "RGBA")

    # Glyph geometry inside a centered safe area (Apple uses ~80% content area).
    pad = int(size * 0.22)
    inner = size - 2 * pad

    # Stem of the P (left vertical bar).
    stem_w = int(inner * (0.30 if simplified else 0.26))
    stem_x0 = pad
    stem_y0 = pad
    stem_x1 = stem_x0 + stem_w
    stem_y1 = pad + inner
    stem_radius = int(stem_w * 0.45)
    draw.rounded_rectangle(
        (stem_x0, stem_y0, stem_x1, stem_y1),
        radius=stem_radius,
        fill=COLOR_GLYPH,
    )

    # Bowl of the P (upper ring). Slight overlap with the stem so they fuse.
    bowl_outer_d = int(inner * (0.78 if simplified else 0.72))
    bowl_x0 = stem_x0 + int(stem_w * 0.55)
    bowl_y0 = pad
    bowl_x1 = bowl_x0 + bowl_outer_d
    bowl_y1 = bowl_y0 + bowl_outer_d
    # Don't let the bowl exceed the safe area on the right.
    overflow = bowl_x1 - (pad + inner)
    if overflow > 0:
        bowl_x1 -= overflow
        bowl_x0 -= overflow
    draw.ellipse((bowl_x0, bowl_y0, bowl_x1, bowl_y1), fill=COLOR_GLYPH)

    # Hole in the bowl -> shows the gradient through, like a doorway / port opening.
    ring_w = int(bowl_outer_d * (0.30 if simplified else 0.34))
    hole_x0 = bowl_x0 + ring_w
    hole_y0 = bowl_y0 + ring_w
    hole_x1 = bowl_x1 - ring_w
    hole_y1 = bowl_y1 - ring_w
    # Cut a transparent hole by drawing onto the alpha channel.
    hole_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(hole_mask).ellipse((hole_x0, hole_y0, hole_x1, hole_y1), fill=255)
    # Punch through alpha of canvas.
    alpha = canvas.split()[-1]
    new_alpha = Image.eval(hole_mask, lambda v: 0 if v == 255 else 255)
    # Combine: keep existing alpha where new_alpha is 255, transparent inside hole.
    combined_alpha = Image.new("L", canvas.size, 0)
    combined_alpha.paste(alpha, (0, 0))
    combined_alpha.paste(0, (0, 0), hole_mask)
    canvas.putalpha(combined_alpha)


def render_master(size: int, simplified: bool) -> Image.Image:
    """Render the icon at the given pixel size."""
    # Background = gradient clipped to the squircle.
    bg = vertical_gradient(size, COLOR_TOP, COLOR_BOTTOM).convert("RGBA")
    mask = rounded_squircle_mask(size)

    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile.paste(bg, (0, 0), mask)

    # Subtle top highlight for that macOS sheen (skip on small icons).
    if size >= 128:
        highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        hd = ImageDraw.Draw(highlight)
        hd.ellipse(
            (-int(size * 0.2), -int(size * 0.6), int(size * 1.2), int(size * 0.35)),
            fill=(255, 255, 255, 38),
        )
        highlight = highlight.filter(ImageFilter.GaussianBlur(size * 0.02))
        # Clip highlight to squircle.
        clipped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        clipped.paste(highlight, (0, 0), mask)
        tile = Image.alpha_composite(tile, clipped)

    # Glyph layer with soft shadow (shadow skipped at very small sizes).
    glyph_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_glyph_P(glyph_layer, simplified=simplified)

    if size >= 64:
        shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        sd_mask = glyph_layer.split()[-1]
        ImageDraw.Draw(shadow).bitmap((0, max(1, int(size * 0.008))), sd_mask, fill=COLOR_GLYPH_SHADOW)
        shadow = shadow.filter(ImageFilter.GaussianBlur(max(1, size * 0.012)))
        # Clip shadow to tile.
        shadow_clipped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        shadow_clipped.paste(shadow, (0, 0), mask)
        tile = Image.alpha_composite(tile, shadow_clipped)

    # Clip glyph itself to the tile so any overshoot is hidden.
    glyph_clipped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glyph_clipped.paste(glyph_layer, (0, 0), mask)
    tile = Image.alpha_composite(tile, glyph_clipped)

    return tile


def main() -> None:
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    # Master at 1024 (detailed) and a simplified master for small sizes.
    master_detailed = render_master(1024, simplified=False)
    master_simple = render_master(1024, simplified=True)

    for filename, px in SIZES:
        src = master_simple if px <= 64 else master_detailed
        img = src.resize((px, px), Image.LANCZOS)
        out = ICONSET_DIR / filename
        img.save(out, format="PNG", optimize=True)
        print(f"wrote {out} ({px}x{px})")


if __name__ == "__main__":
    main()
