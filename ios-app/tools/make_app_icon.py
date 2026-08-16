#!/usr/bin/env python3
"""Genera l'icona dell'app.

Niente librerie esterne: l'immagine viene disegnata pixel per pixel con la
matematica delle distanze con segno (SDF) e salvata come PNG con `zlib`.

Il soggetto è la banconota dell'app — inclinata, argentata su fondo nero, con
il simbolo del dollaro inciso al centro — così l'icona sulla schermata Home
racconta la stessa cosa della prima schermata dell'app.

    python3 tools/make_app_icon.py
"""

import math
import struct
import zlib
from pathlib import Path

# --- Parametri, in punti di un'icona da 1024 --------------------------------

SIZE = 1024
SUPERSAMPLE = 2          # si disegna al doppio e si riduce: bordi puliti
TILT_DEGREES = -14.0

NOTE_WIDTH = 700.0
NOTE_ASPECT = 2.05
NOTE_CORNER = 46.0
INNER_INSET = 26.0
INNER_STROKE = 5.0

SILVER_TOP = (0xF4, 0xF4, 0xF6)
SILVER_BOTTOM = (0x8C, 0x8C, 0x92)
ENGRAVED = (0x15, 0x15, 0x17)

GLYPH_RADIUS = 40.0      # raggio delle due curve della "S"
GLYPH_STROKE = 21.0

OUTPUT = Path(__file__).resolve().parent.parent / \
    "Cash/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"


def rounded_rect_sdf(x, y, half_width, half_height, radius):
    """Distanza con segno dal bordo di un rettangolo con angoli arrotondati.

    Negativa dentro, positiva fuori, zero esattamente sul bordo: è il valore
    che permette di sfumare il contorno di un pixel invece di tagliarlo netto.
    """
    qx = abs(x) - (half_width - radius)
    qy = abs(y) - (half_height - radius)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - radius


def dollar_sdf(x, y, radius, stroke):
    """La "S" del dollaro, costruita con due archi e una barra verticale.

    Ogni arco è un anello a cui si toglie un quadrante: al cerchio superiore
    manca il pezzo in basso a destra, a quello inferiore il pezzo in alto a
    sinistra. Uniti, i due archi disegnano una S.
    """
    far = 1e9

    # Arco superiore, centro a (0, -radius).
    ux, uy = x, y + radius
    upper = abs(math.hypot(ux, uy) - radius) - stroke / 2
    if ux > 0 and uy > 0:
        upper = far

    # Arco inferiore, centro a (0, +radius).
    vx, vy = x, y - radius
    lower = abs(math.hypot(vx, vy) - radius) - stroke / 2
    if vx < 0 and vy < 0:
        lower = far

    # La barra che attraversa la S da parte a parte.
    bar = max(abs(x) - stroke * 0.30, abs(y) - (2 * radius + stroke * 0.85))

    return min(upper, lower, bar)


def clamp01(value):
    return 0.0 if value < 0.0 else (1.0 if value > 1.0 else value)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def render():
    scale = SUPERSAMPLE
    width = SIZE * scale
    pixels = bytearray(width * width * 3)      # zero = nero pieno

    angle = math.radians(TILT_DEGREES)
    cos_a, sin_a = math.cos(angle), math.sin(angle)

    center = width / 2.0
    half_w = NOTE_WIDTH / 2 * scale
    half_h = (NOTE_WIDTH / NOTE_ASPECT) / 2 * scale
    corner = NOTE_CORNER * scale
    inset = INNER_INSET * scale
    inner_stroke = INNER_STROKE * scale
    glyph_radius = GLYPH_RADIUS * scale
    glyph_stroke = GLYPH_STROKE * scale

    # Si disegna solo il rettangolo che contiene la banconota inclinata:
    # tutto il resto è già nero e non serve toccarlo.
    reach_x = abs(half_w * cos_a) + abs(half_h * sin_a) + 4 * scale
    reach_y = abs(half_w * sin_a) + abs(half_h * cos_a) + 4 * scale
    x_from, x_to = int(center - reach_x), int(center + reach_x) + 1
    y_from, y_to = int(center - reach_y), int(center + reach_y) + 1

    for py in range(max(0, y_from), min(width, y_to)):
        dy = py + 0.5 - center
        row = py * width * 3

        for px in range(max(0, x_from), min(width, x_to)):
            dx = px + 0.5 - center

            # Coordinate locali della banconota: si annulla l'inclinazione.
            lx = dx * cos_a + dy * sin_a
            ly = -dx * sin_a + dy * cos_a

            edge = rounded_rect_sdf(lx, ly, half_w, half_h, corner)
            alpha = clamp01(0.5 - edge)
            if alpha <= 0.0:
                continue

            # Gradiente verticale: la luce cade dall'alto.
            t = clamp01((ly + half_h) / (2 * half_h))
            color = mix(SILVER_TOP, SILVER_BOTTOM, t)

            # Filetto interno inciso.
            inner = rounded_rect_sdf(
                lx, ly, half_w - inset, half_h - inset, max(corner - inset * 0.6, 1.0)
            )
            line = clamp01(1.0 - abs(inner) / (inner_stroke / 2))
            if line > 0:
                color = mix(color, ENGRAVED, line * 0.30)

            # Il simbolo del dollaro.
            glyph = clamp01(0.5 - dollar_sdf(lx, ly, glyph_radius, glyph_stroke))
            if glyph > 0:
                color = mix(color, ENGRAVED, glyph)

            index = row + px * 3
            pixels[index] = int(color[0] * alpha)
            pixels[index + 1] = int(color[1] * alpha)
            pixels[index + 2] = int(color[2] * alpha)

    return downsample(pixels, width, scale)


def downsample(pixels, width, factor):
    """Media dei blocchi factor×factor: è qui che nasce l'antialiasing."""
    if factor == 1:
        return pixels

    out_size = width // factor
    out = bytearray(out_size * out_size * 3)
    samples = factor * factor

    for y in range(out_size):
        for x in range(out_size):
            r = g = b = 0
            for sy in range(factor):
                base = ((y * factor + sy) * width + x * factor) * 3
                for sx in range(factor):
                    i = base + sx * 3
                    r += pixels[i]
                    g += pixels[i + 1]
                    b += pixels[i + 2]

            i = (y * out_size + x) * 3
            out[i] = r // samples
            out[i + 1] = g // samples
            out[i + 2] = b // samples

    return out


def write_png(path, size, rgb):
    """PNG a 8 bit senza canale alfa: le icone iOS non possono averlo."""
    raw = bytearray()
    stride = size * 3
    for y in range(size):
        raw.append(0)                                  # filtro "None"
        raw += rgb[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        payload = tag + data
        return (
            struct.pack(">I", len(data))
            + payload
            + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


if __name__ == "__main__":
    write_png(OUTPUT, SIZE, render())
    print(f"Icona scritta: {OUTPUT} ({OUTPUT.stat().st_size} byte)")
