"""Draw the textures of two more skins (original artwork, LifeTimeStats' own):
  Stone & Gold    - in the style of Altoholic: dark stone, steel rails with a gold bevel, a round
                    portrait ring, a gold highlight bar for the selected entry.
  Adventure Journal - in the style of Dungeon Journal: dark brown leather inside a darker frame with
                    a thin gold line.

Run: python scripts/make_styled_textures.py   (needs Pillow)
Writes Media/styled/*.tga, all power-of-two 32-bit TGA:
  rock      256x256  tileable dark stone
  leather   256x256  tileable dark brown leather
  sedge_h   512x32   steel rail with a gold inner bevel (top; flipped for the bottom)
  sedge_v   32x512   the same, upright
  jedge_h   512x32   dark brown rail with a thin gold line
  jedge_v   32x512   the same, upright
  rivet     64x64    gold corner plate with a rivet
  ring      128x128  gold ring around the portrait
  hbar      256x32   highlight bar fading to the right (white, tinted)
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Media" / "styled"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(1616)
GOLD = (206, 166, 74, 255)
GOLD_D = (120, 90, 34, 255)
GOLD_L = (246, 220, 140, 255)


def save(img, name):
    img.save(OUT / (name + ".tga"))
    print("wrote", name, img.size)


def tile_noise(size, cells, blur):
    small = Image.new("L", (cells, cells))
    small.putdata([random.randint(0, 255) for _ in range(cells * cells)])
    big = Image.new("L", (cells * 3, cells * 3))
    for x in range(3):
        for y in range(3):
            big.paste(small, (x * cells, y * cells))
    big = big.resize((size * 3, size * 3), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))
    return big.crop((size, size, size * 2, size * 2))


def tinted(noises, base, weights, spread=1.0):
    out = Image.new("RGBA", noises[0].size)
    o = out.load()
    px = [n.load() for n in noises]
    w, h = out.size
    for y in range(h):
        for x in range(w):
            k = sum((p[x, y] - 128) * wt for p, wt in zip(px, weights))
            o[x, y] = tuple(max(0, min(255, int(c + k * spread))) for c in base) + (255,)
    return out


# ---------------------------------------------------------------- stone and leather
save(tinted([tile_noise(256, 10, 6), tile_noise(256, 40, 1.5), tile_noise(256, 120, 0.6)], (40, 40, 42), (0.16, 0.10, 0.06)), "rock")
save(tinted([tile_noise(256, 8, 8), tile_noise(256, 60, 1.0), tile_noise(256, 160, 0.5)], (38, 26, 17), (0.10, 0.05, 0.05)), "leather")


def rail(w, h, horizontal, base, line, bevel):
    n = tile_noise(max(w, h), 30, 1.2).resize((w, h))
    out = tinted([n], base, (0.12,))
    d = ImageDraw.Draw(out)
    across = h if horizontal else w
    for i in range(across):
        t = i / (across - 1)
        shade = int(-40 + 60 * (1 - abs(t - 0.45) * 1.6)) if bevel else int(-30 + 40 * t)
        for j in range(w if horizontal else h):
            xy = (j, i) if horizontal else (i, j)
            r, g, b, a = out.getpixel(xy)
            out.putpixel(xy, (max(0, min(255, r + shade)), max(0, min(255, g + shade)), max(0, min(255, b + shade)), a))
    if horizontal:
        d.line([(0, h - 5), (w, h - 5)], fill=GOLD_D, width=3)
        d.line([(0, h - 5), (w, h - 5)], fill=line, width=1)
        d.line([(0, 1), (w, 1)], fill=(10, 10, 10, 255), width=2)
    else:
        d.line([(w - 5, 0), (w - 5, h)], fill=GOLD_D, width=3)
        d.line([(w - 5, 0), (w - 5, h)], fill=line, width=1)
        d.line([(1, 0), (1, h)], fill=(10, 10, 10, 255), width=2)
    return out


save(rail(512, 32, True, (72, 74, 80), GOLD, True), "sedge_h")
save(rail(32, 512, False, (72, 74, 80), GOLD, True), "sedge_v")
save(rail(512, 32, True, (52, 34, 22), GOLD_L, False), "jedge_h")
save(rail(32, 512, False, (52, 34, 22), GOLD_L, False), "jedge_v")

# ---------------------------------------------------------------- gold corner plate with a rivet
big = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.polygon([(0, 0), (190, 0), (190, 60), (60, 60), (60, 190), (0, 190)], fill=GOLD_D)
d.polygon([(10, 10), (176, 10), (176, 48), (48, 48), (48, 176), (10, 176)], fill=GOLD)
d.ellipse((14, 14, 46, 46), fill=GOLD_L, outline=GOLD_D, width=6)
save(big.resize((64, 64), Image.LANCZOS), "rivet")

# ---------------------------------------------------------------- portrait ring
big = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.ellipse((12, 12, 500, 500), outline=GOLD_D, width=44)
d.ellipse((22, 22, 490, 490), outline=GOLD, width=24)
d.ellipse((40, 40, 472, 472), outline=GOLD_L, width=6)
save(big.resize((128, 128), Image.LANCZOS), "ring")

# ---------------------------------------------------------------- highlight bar
img = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
p = img.load()
for x in range(256):
    a = int(255 * (1 - x / 255) ** 0.8)
    for y in range(32):
        edge = min(y, 31 - y)
        p[x, y] = (255, 255, 255, int(a * min(1, 0.35 + edge / 10)))
save(img, "hbar")
