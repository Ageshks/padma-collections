#!/usr/bin/env python3
"""Derive the app's brand assets from assets/images/logo.png.

The uploaded logo is a 1408x768 (1.833:1) *full-bleed* brand board: a dark navy
photographic backdrop with the gold crest, "PADMA / COLLECTIONS / EST. 2026",
and a decorative sparkle bottom-right.

It cannot be dropped into the app as-is, because:

  * it is fully opaque, so on the cream surfaces used across the app it would
    render as a hard dark rectangle;
  * it is 1.78 MB, which is wasteful to bundle;
  * `flutter_launcher_icons` points at `assets/images/icon.png`, which did not
    exist at all.

This script derives the assets the app actually needs, keeping the uploaded
`logo.png` untouched as the source of truth:

  logo_mark.png        crest only, gold on transparency (app bars, avatars)
  logo_wordmark.png    "PADMA COLLECTIONS / EST. 2026", gold on transparency
                       (for light/cream surfaces)
  logo_full.png        crest + wordmark lockup on transparency (splash, login)
  icon.png             1024x1024 launcher source: navy plate + centred crest

Keying notes
------------
The artwork cannot be isolated by brightness alone. The sapphire stones set
into the crest have a luma of ~21, which is *darker* than the navy backdrop, so
a naive luminance key punches holes straight through the emblem.

Instead the backdrop is removed with a border-connected flood fill: only
background pixels reachable from the image edge are treated as backdrop, so
enclosed dark detail inside the crest survives. A soft matte is then built from
how far each pixel sits from that backdrop, and colours are unpremultiplied
against the estimated backdrop to kill the dark fringe on thin gold strokes.

That enclosure rule must be switched off for the wordmark. Its letters are gold
strokes with open counters, and the navy inside the bowl of the "D" is backdrop
reaching the fill only *through* the letter, so the flood fill strands it as
opaque navy blobs. With no dark artwork in that region, a flat matte keys it out
cleanly -- the separation is easy there (backdrop luma <= 28, gold >= 180).

Usage:  python3 tool/generate_logo_assets.py
"""

from __future__ import annotations

import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ROOT, "assets", "images")
SOURCE = os.path.join(IMAGES, "logo.png")

# Average of the logo's own backdrop, sampled away from the artwork.
BRAND_NAVY = (10, 17, 34)

# A pixel counts as backdrop when it is dark enough and close enough to the
# navy backdrop. The thresholds are deliberately generous: the crest has a
# soft glow halo around it that is much brighter than the navy itself, and a
# tight threshold strands that halo as opaque dark blobs beside the artwork.
# 135/145 was chosen by sweeping candidates and checking that the halo clears
# while the enclosed sapphires and diamond facets survive.
BG_MAX_LUMA = 135
BG_MAX_DIST = 145

# Soft matte ramp: fully transparent below, fully opaque above.
MATE_LO = 34
MATE_HI = 122

# How far the soft matte reaches inwards from the detected backdrop, in px.
MATE_REACH = 3

def _clamp(value: float) -> int:
    return 0 if value < 0 else (255 if value > 255 else int(value))


def _luma(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b


def _dist(px: tuple[int, int, int], ref: tuple[int, int, int]) -> float:
    return (
        (px[0] - ref[0]) ** 2 + (px[1] - ref[1]) ** 2 + (px[2] - ref[2]) ** 2
    ) ** 0.5


def is_backdrop(px: tuple[int, int, int]) -> bool:
    """True when a pixel plausibly belongs to the photographic backdrop."""
    return (
        _luma(*px) < BG_MAX_LUMA
        and _dist(px, BRAND_NAVY) < BG_MAX_DIST
    )


def backdrop_mask(image: Image.Image) -> bytearray:
    """1 = backdrop, reachable from the border through backdrop-like pixels.

    Border-connected flood fill: dark detail *enclosed* by the goldwork (the
    sapphires) is never reached, so it is preserved as artwork.
    """
    width, height = image.size
    px = image.load()
    mask = bytearray(width * height)

    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        idx = y * width + x
        if mask[idx]:
            return
        if not is_backdrop(px[x, y]):
            return
        mask[idx] = 1
        queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            push(x - 1, y)
        if x < width - 1:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y < height - 1:
            push(x, y + 1)

    return mask


def key_backdrop(image: Image.Image, preserve_enclosed: bool = True) -> Image.Image:
    """Composite `image` over transparency, removing the backdrop.

    `preserve_enclosed` keeps dark detail that the goldwork *encloses* (the
    sapphires and stone facets inside the crest), which a naive key would punch
    through. Pass False for the wordmark, whose letter counters are holes full of
    plain backdrop and must be removed rather than kept.
    """
    src = image.convert("RGB")
    width, height = src.size
    px = src.load()

    if preserve_enclosed:
        mask = backdrop_mask(src)
    else:
        # Flat matte: every backdrop-like pixel goes, enclosed or not.
        mask = bytearray(
            1 if is_backdrop(px[x, y]) else 0
            for y in range(height)
            for x in range(width)
        )

    # Distance (in steps) outward from the detected backdrop, capped at
    # MATE_REACH, so only the transition band gets a soft edge.
    reach = bytearray(width * height)
    wave: deque[tuple[int, int]] = deque()
    for y in range(height):
        for x in range(width):
            if mask[y * width + x]:
                wave.append((x, y))

    for x, y in wave:
        reach[y * width + x] = MATE_REACH

    depth = MATE_REACH
    while depth > 0 and wave:
        nxt: deque[tuple[int, int]] = deque()
        while wave:
            x, y = wave.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    idx = ny * width + nx
                    if not mask[idx] and not reach[idx]:
                        reach[idx] = depth
                        nxt.append((nx, ny))
        wave = nxt
        depth -= 1

    out = Image.new("RGBA", (width, height))
    out_px = out.load()
    span = float(MATE_HI - MATE_LO)

    for y in range(height):
        for x in range(width):
            idx = y * width + x
            if mask[idx]:
                continue  # backdrop -> fully transparent

            r, g, b = px[x, y]
            if not reach[idx]:
                # Enclosed artwork (sapphires, stone facets): keep as-is.
                out_px[x, y] = (r, g, b, 255)
                continue

            alpha = (_luma(r, g, b) - MATE_LO) / span
            alpha = 0.0 if alpha < 0 else (1.0 if alpha > 1 else alpha)

            if alpha <= 0.004:
                out_px[x, y] = (0, 0, 0, 0)
                continue

            # Un-premultiply against the backdrop to remove the dark fringe.
            inv = 1.0 - alpha
            out_px[x, y] = (
                _clamp((r - inv * BRAND_NAVY[0]) / alpha),
                _clamp((g - inv * BRAND_NAVY[1]) / alpha),
                _clamp((b - inv * BRAND_NAVY[2]) / alpha),
                _clamp(alpha * 255),
            )

    return out


def _longest_run(flags: list[bool]) -> tuple[int, int]:
    """Longest contiguous run of True, as (start, end_inclusive)."""
    best = (-1, -1)
    start = None
    for i, on in enumerate(flags):
        if on and start is None:
            start = i
        elif not on and start is not None:
            if i - 1 - start > best[1] - best[0]:
                best = (start, i - 1)
            start = None
    if start is not None and len(flags) - 1 - start > best[1] - best[0]:
        best = (start, len(flags) - 1)
    return best


def is_luma_ink(px: tuple[int, int, int], threshold: int = 150) -> bool:
    """True when a pixel is brighter than `threshold`.

    Used for the crest, which is one connected wreath shape.
    """
    return _luma(*px) > threshold


def is_gold(px: tuple[int, int, int]) -> bool:
    """True for the warm gold of the wordmark lettering.

    Brightness alone is useless here: the silk backdrop peaks at luma 250,
    brighter than parts of the gold. Colour is the reliable discriminator --
    the lettering is warm (r well above b) and the navy backdrop is not.
    """
    r, g, b = px
    return r > 115 and (r - b) > 50 and r >= g >= b


def ink_extent(
    image: Image.Image,
    box: tuple[int, int, int, int],
    test=is_luma_ink,
) -> tuple[int, int, int, int]:
    """Tight bounding box of the artwork inside `box`.

    `test` decides what counts as artwork: luminance for the crest (a single
    connected wreath), gold-chroma for the wordmark (separate letter strokes,
    which a longest-run rule would otherwise cut apart).
    """
    x0, y0, x1, y1 = box
    crop = image.crop(box)
    w, h = crop.size
    px = crop.load()

    cols = [any(test(px[x, y]) for y in range(0, h, 2)) for x in range(w)]
    if test is is_luma_ink:
        ca, cb = _longest_run(cols)
    else:
        keep = [i for i, on in enumerate(cols) if on]
        ca, cb = (keep[0], keep[-1]) if keep else (-1, -1)
    if ca < 0:
        return (x0, y0, x0, y1)

    rows = [any(test(px[x, y]) for x in range(ca, cb + 1, 2)) for y in range(h)]
    if test is is_luma_ink:
        ra, rb = _longest_run(rows)
    else:
        keep = [i for i, on in enumerate(rows) if on]
        ra, rb = (keep[0], keep[-1]) if keep else (0, 0)
    return (x0 + ca, y0 + ra, x0 + cb + 1, y0 + rb + 1)


def pad(box, amount: int, size):
    """Expand `box` symmetrically, clamped to the image bounds."""
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, h = (x1 - x0) + amount * 2, (y1 - y0) + amount * 2
    x0 = max(0, int(round(cx - w / 2)))
    y0 = max(0, int(round(cy - h / 2)))
    return (x0, y0, min(size[0], x0 + w), min(size[1], y0 + h))


def trim(image: Image.Image) -> Image.Image:
    """Crop fully-transparent margins so the asset is tightly framed."""
    bbox = image.split()[3].getbbox()
    return image.crop(bbox) if bbox else image


def save(image: Image.Image, name: str) -> None:
    path = os.path.join(IMAGES, name)
    image.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) / 1024
    print(f"  {name:<22} {image.size[0]}x{image.size[1]}  {kb:6.1f} KB")


def stack(parts: list[Image.Image], gap: int) -> Image.Image:
    """Vertically stack images, horizontally centred, on transparency."""
    width = max(p.size[0] for p in parts)
    height = sum(p.size[1] for p in parts) + gap * (len(parts) - 1)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    y = 0
    for part in parts:
        canvas.alpha_composite(part, ((width - part.size[0]) // 2, y))
        y += part.size[1] + gap
    return canvas


def main() -> None:
    src = Image.open(SOURCE).convert("RGB")
    size = src.size
    print(f"source logo.png {size[0]}x{size[1]}")

    # Crest occupies roughly y 116..510; the wordmark starts at y 516, so the
    # search box stops there to avoid bleeding into "PADMA".
    crest_box = pad(ink_extent(src, (300, 40, 1180, 512)), 24, size)
    print(f"  crest box    {crest_box}")
    mark = trim(key_backdrop(src.crop(crest_box)))
    save(mark, "logo_mark.png")

    word_box = pad(ink_extent(src, (300, 514, 1180, 712), test=is_gold), 20, size)
    print(f"  wordmark box {word_box}")
    # preserve_enclosed=False: the counters of D/A/O are holes full of backdrop,
    # not artwork, so they must be keyed out like any other background.
    wordmark = trim(key_backdrop(src.crop(word_box), preserve_enclosed=False))
    save(wordmark, "logo_wordmark.png")

    # Full lockup: crest above wordmark, both keyed, on transparency.
    gap = round(mark.size[0] * 0.16)
    save(stack([mark, wordmark], gap), "logo_full.png")

    # Launcher icon. Adaptive icons crop to a 66% safe zone, so the crest sits
    # at ~58% of the canvas on a navy plate matching the logo backdrop.
    plate = 1024
    icon = Image.new("RGBA", (plate, plate), BRAND_NAVY + (255,))
    scale = (plate * 0.58) / max(mark.size)
    resized = mark.resize(
        (max(1, round(mark.size[0] * scale)), max(1, round(mark.size[1] * scale))),
        Image.LANCZOS,
    )
    icon.alpha_composite(
        resized,
        ((plate - resized.size[0]) // 2, (plate - resized.size[1]) // 2),
    )
    save(icon.convert("RGB"), "icon.png")


if __name__ == "__main__":
    main()