#!/usr/bin/env python3
"""Generate a simple 1024x1024 app icon placeholder without third-party modules."""
import math
import struct
import sys
import zlib

SIZE = 1024
BG_TOP = (47, 107, 255)
BG_BOTTOM = (28, 62, 168)
FG = (255, 255, 255)


def inside_rounded_square(x, y):
    inset = SIZE * 0.02
    radius = SIZE * 0.22
    left, top = inset, inset
    right, bottom = SIZE - inset, SIZE - inset
    if x < left or x > right or y < top or y > bottom:
        return False
    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    return math.hypot(x - cx, y - cy) <= radius


def keyhole(x, y):
    cx = SIZE / 2
    head_y = SIZE * 0.42
    head_r = SIZE * 0.135
    if math.hypot(x - cx, y - head_y) <= head_r:
        return True
    t = (y - head_y) / (SIZE * 0.26)
    if 0 <= t <= 1:
        width = head_r * (0.62 - 0.34 * t)
        if abs(x - cx) <= width:
            return True
    return False


def build_rows():
    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            t = y / (SIZE - 1)
            r = round(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t)
            g = round(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t)
            b = round(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t)
            if inside_rounded_square(x, y) and keyhole(x, y):
                r, g, b = FG
            row += struct.pack("BBBB", r, g, b, 255)
        rows.append(bytes(row))
    return b"".join(rows)


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png"
    raw = build_rows()
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(out, "wb") as fh:
        fh.write(png)
    print("wrote", out)


if __name__ == "__main__":
    main()
