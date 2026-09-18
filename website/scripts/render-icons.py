#!/usr/bin/env python3
"""Render the Astra app icon to PNG without any image libraries.

The icon mirrors the site header's mark: a rounded-square gradient tile with an
accent border, the four-point sparkle, and the small companion dot. Everything
is drawn in the 24-unit viewBox of assets/app-icon.svg, scaled to the target
pixel size. Anti-aliased with 3x3 supersampling; PNG written via zlib/struct.
"""
import math
import struct
import zlib

# Geometry in the 24-unit viewBox (matches assets/app-icon.svg).
BOX_INSET = 1.0
BOX_CORNER = 5.5
BORDER_W = 0.9
STAR = [
    (12.0, 2.6), (14.05, 9.2), (20.65, 11.25), (14.05, 13.3),
    (12.0, 19.9), (9.95, 13.3), (3.35, 11.25), (9.95, 9.2),
]
DOT_CX, DOT_CY, DOT_R = 19.0, 18.4, 1.5
GX, GY, GS = 4.8, 4.8, 0.6  # sparkle group: translate(4.8 4.8) scale(0.6)

BG_TOP = (0x2E, 0x21, 0x58)
BG_BOTTOM = (0x0D, 0x09, 0x20)
BORDER = (0x9B, 0x7B, 0xF7)
SPARKLE = (0xCD, 0xB9, 0xFF)


def rounded_box_sdf(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def seg_dist(px, py, x1, y1, x2, y2):
    vx, vy = x2 - x1, y2 - y1
    wx, wy = px - x1, py - y1
    denom = vx * vx + vy * vy
    t = 0.0 if denom == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / denom))
    return math.hypot(wx - t * vx, wy - t * vy)


def star_sdf(x, y):
    """Signed distance to the sparkle, in viewBox units (negative inside)."""
    # Inverse of translate(4.8,4.8) scale(0.6) -> grid space.
    gx = (x - GX) / GS
    gy = (y - GY) / GS
    n = len(STAR)
    best = min(seg_dist(gx, gy, *STAR[i], *STAR[(i + 1) % n]) for i in range(n))
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = STAR[i]
        xj, yj = STAR[j]
        if (yi > gy) != (yj > gy) and gx < (xj - xi) * (gy - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return (-best if inside else best) * GS


def coverage(d):
    """0..1 coverage from signed distance (negative = fully inside)."""
    return max(0.0, min(1.0, 0.5 - d))


def render(size):
    s = size / 24.0  # viewBox units -> pixels
    half_px = size / 2.0
    hw_px = half_px - BOX_INSET * s
    corner_px = BOX_CORNER * s
    border_px = BORDER_W * s
    dot_px = (GX + DOT_CX * GS) * s, (GY + DOT_CY * GS) * s, DOT_R * GS * s

    rows = []
    for py in range(size):
        row = bytearray()
        for px in range(size):
            r = g = b = a = 0.0
            for oy in range(3):
                for ox in range(3):
                    x = px + (ox + 0.5) / 3.0
                    y = py + (oy + 0.5) / 3.0

                    d_box = rounded_box_sdf(x, y, half_px, half_px, hw_px, hw_px, corner_px)
                    cov_box = coverage(d_box)
                    if cov_box <= 0:
                        continue

                    # diagonal background gradient
                    t = (x + y) / (2.0 * size)
                    cr = BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t
                    cg = BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t
                    cb = BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t

                    # border ring just inside the tile edge
                    if -d_box < border_px:
                        fade = max(0.0, min(1.0, -d_box / border_px))
                        cr += (BORDER[0] - cr) * (0.55 * fade)
                        cg += (BORDER[1] - cg) * (0.55 * fade)
                        cb += (BORDER[2] - cb) * (0.55 * fade)

                    # sparkle + companion dot
                    cov_glyph = max(
                        coverage(star_sdf(x / s, y / s) * s),
                        coverage(math.hypot(x - dot_px[0], y - dot_px[1]) - dot_px[2]) * 0.7,
                    )
                    if cov_glyph > 0:
                        cr += (SPARKLE[0] - cr) * cov_glyph
                        cg += (SPARKLE[1] - cg) * cov_glyph
                        cb += (SPARKLE[2] - cb) * cov_glyph

                    r += cr * cov_box
                    g += cg * cov_box
                    b += cb * cov_box
                    a += cov_box
            if a > 0:
                row += bytes(
                    (
                        min(255, int(r / a)),
                        min(255, int(g / a)),
                        min(255, int(b / a)),
                        min(255, int(a * 255 / 9.0)),
                    )
                )
            else:
                row += b"\x00\x00\x00\x00"
        rows.append(bytes(row))
    return rows


def write_png(path, size, rows):
    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)
    print(f"wrote {path} ({size}x{size})")


if __name__ == "__main__":
    for path, size in [
        ("app/icon.png", 96),
        ("app/apple-icon.png", 180),
        ("public/icons/icon-192.png", 192),
        ("public/icons/icon-512.png", 512),
    ]:
        write_png(path, size, render(size))
