"""Draw the textures of the framed tome skins, Lifetime Stats and Stats Explorer (original artwork).

Run: python scripts/make_framed_textures.py   (needs Pillow)
Writes Media/framed/*.tga, all power-of-two 32-bit TGA:
  parchment  1024x1024  clean aged parchment for the window's interior
  wood       256x256    dark wood for the Stats Explorer menu
  edge_h     512x32     dark wood frame rail with a gold inner line (top; flipped for the bottom)
  edge_v     32x512     the same, upright (left; flipped for the right)
  corner     64x64      gold corner ornament (top-left; flipped for the others)
  plaque     512x128    the title plaque over the top edge
  emblem     128x128    gold compass star
  crest      128x128    white shield (tinted per card) and crest_rim, its gold rim
  navsel     256x32     menu selection, pointed on the right (white, tinted)
  divider    256x16     an ornamental rule with a diamond (white, tinted)
  arrow      32x32      the dropdown chevron (white, tinted)
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Media" / "framed"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(2026)

GOLD = (201, 160, 84, 255)
GOLD_D = (122, 88, 38, 255)
GOLD_L = (238, 210, 140, 255)


def save(img, name):
    img.save(OUT / (name + ".tga"))
    print("wrote", name, img.size)


def noise(w, h, cells_x, cells_y, blur):
    small = Image.new("L", (cells_x, cells_y))
    small.putdata([random.randint(0, 255) for _ in range(cells_x * cells_y)])
    return small.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))


# ---------------------------------------------------------------- parchment
N = 1024
coarse, mid, fine = noise(N, N, 14, 14, 26), noise(N, N, 60, 60, 4), noise(N, N, 300, 300, 0.7)
img = Image.new("RGBA", (N, N))
px = img.load()
cp, mp, fp = coarse.load(), mid.load(), fine.load()
for y in range(N):
    for x in range(N):
        k = (cp[x, y] - 128) * 0.12 + (mp[x, y] - 128) * 0.05 + (fp[x, y] - 128) * 0.05
        dx, dy = (x - N / 2) / (N / 2), (y - N / 2) / (N / 2)
        k -= ((dx * dx + dy * dy) ** 1.4) * 34
        px[x, y] = (max(0, min(255, int(226 + k))), max(0, min(255, int(208 + k * 0.97))), max(0, min(255, int(168 + k * 0.9))), 255)
save(img, "parchment")

# ---------------------------------------------------------------- dark wood
def wood(w, h, horizontal=True):
    grain = noise(w, h, 6 if horizontal else 90, 90 if horizontal else 6, 1.2)
    streak = noise(w, h, 3 if horizontal else 40, 40 if horizontal else 3, 2)
    out = Image.new("RGBA", (w, h))
    o, g, s = out.load(), grain.load(), streak.load()
    for y in range(h):
        for x in range(w):
            k = (g[x, y] - 128) * 0.18 + (s[x, y] - 128) * 0.12
            o[x, y] = (max(0, min(255, int(58 + k))), max(0, min(255, int(40 + k * 0.8))), max(0, min(255, int(26 + k * 0.6))), 255)
    return out


save(wood(256, 256, horizontal=True), "wood")


def rail(w, h, horizontal):
    """A frame rail: wood, a dark outer edge, a bevel and a gold line on the inner side."""
    out = wood(w, h, horizontal)
    d = ImageDraw.Draw(out)
    across = h if horizontal else w
    for i in range(across):
        # inner side is the far side (bottom for a horizontal rail, right for an upright one)
        t = i / (across - 1)
        shade = int(-50 + 70 * min(1, t * 1.6))
        if horizontal:
            for x in range(w):
                r, g, b, a = out.getpixel((x, i))
                out.putpixel((x, i), (max(0, min(255, r + shade)), max(0, min(255, g + shade)), max(0, min(255, b + shade)), a))
        else:
            for y in range(h):
                r, g, b, a = out.getpixel((i, y))
                out.putpixel((i, y), (max(0, min(255, r + shade)), max(0, min(255, g + shade)), max(0, min(255, b + shade)), a))
    if horizontal:
        d.line([(0, h - 6), (w, h - 6)], fill=GOLD_D, width=3)
        d.line([(0, h - 6), (w, h - 6)], fill=GOLD, width=1)
        d.line([(0, h - 2), (w, h - 2)], fill=(30, 20, 12, 255), width=2)
        d.line([(0, 1), (w, 1)], fill=(20, 14, 8, 255), width=2)
    else:
        d.line([(w - 6, 0), (w - 6, h)], fill=GOLD_D, width=3)
        d.line([(w - 6, 0), (w - 6, h)], fill=GOLD, width=1)
        d.line([(w - 2, 0), (w - 2, h)], fill=(30, 20, 12, 255), width=2)
        d.line([(1, 0), (1, h)], fill=(20, 14, 8, 255), width=2)
    return out


save(rail(512, 32, True), "edge_h")
save(rail(32, 512, False), "edge_v")

# ---------------------------------------------------------------- gold corner
S = 64
img = Image.new("RGBA", (S * 4, S * 4), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
k = 4
d.polygon([(0, 0), (S * k * 0.62, 0), (S * k * 0.62, 18 * k / 4 * 4), (18 * k, 18 * k), (18 * k, S * k * 0.62), (0, S * k * 0.62)], fill=GOLD_D)
d.polygon([(6 * k, 6 * k), (S * k * 0.56, 6 * k), (S * k * 0.56, 13 * k), (13 * k, 13 * k), (13 * k, S * k * 0.56), (6 * k, S * k * 0.56)], fill=GOLD)
for cx, cy in ((S * k * 0.62, 9 * k), (9 * k, S * k * 0.62)):
    d.ellipse((cx - 5 * k, cy - 5 * k, cx + 5 * k, cy + 5 * k), fill=GOLD, outline=GOLD_D, width=k)
d.ellipse((16 * k, 16 * k, 30 * k, 30 * k), fill=GOLD_L, outline=GOLD_D, width=k * 2)
d.polygon([(23 * k, 18 * k), (27 * k, 23 * k), (23 * k, 28 * k), (19 * k, 23 * k)], fill=GOLD_D)
save(img.resize((S, S), Image.LANCZOS), "corner")

# ---------------------------------------------------------------- title plaque
W, H = 512, 128
big = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
body = [(70, 40), (W * 2 - 70, 40), (W * 2 - 20, H), (W * 2 - 70, H * 2 - 40), (70, H * 2 - 40), (20, H)]
d.polygon(body, fill=(44, 30, 20, 255))
inner = [(84, 52), (W * 2 - 84, 52), (W * 2 - 40, H), (W * 2 - 84, H * 2 - 52), (84, H * 2 - 52), (40, H)]
d.line(body + [body[0]], fill=GOLD_D, width=10)
d.line(body + [body[0]], fill=GOLD, width=4)
d.line(inner + [inner[0]], fill=GOLD_D, width=3)
grain = wood(W * 2, H * 2)
mask = Image.new("L", (W * 2, H * 2), 0)
ImageDraw.Draw(mask).polygon(inner, fill=90)
big.paste(grain, (0, 0), mask)
for sx in (1, -1):
    cx = W if sx == 1 else W
    for i in range(3):
        x0 = 40 + i * 14 if sx == 1 else W * 2 - 40 - i * 14
        d.line([(x0, H - 30 + i * 6), (x0 + sx * 8, H), (x0, H + 30 - i * 6)], fill=GOLD, width=4)
save(big.resize((W, H), Image.LANCZOS), "plaque")

# ---------------------------------------------------------------- compass emblem
S = 128
big = Image.new("RGBA", (S * 4, S * 4), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
c = S * 2
d.ellipse((c - 150, c - 150, c + 150, c + 150), outline=GOLD_D, width=22)
d.ellipse((c - 150, c - 150, c + 150, c + 150), outline=GOLD, width=10)
for i in range(8):
    a = i * math.pi / 4 - math.pi / 2
    long = 240 if i % 2 == 0 else 160
    tip = (c + math.cos(a) * long, c + math.sin(a) * long)
    l = (c + math.cos(a - 0.32) * 46, c + math.sin(a - 0.32) * 46)
    r = (c + math.cos(a + 0.32) * 46, c + math.sin(a + 0.32) * 46)
    d.polygon([tip, l, (c, c)], fill=GOLD_L if i % 2 == 0 else GOLD)
    d.polygon([tip, r, (c, c)], fill=GOLD_D)
d.ellipse((c - 34, c - 34, c + 34, c + 34), fill=(46, 92, 76, 255), outline=GOLD, width=10)
save(big.resize((S, S), Image.LANCZOS), "emblem")

# ---------------------------------------------------------------- crest (shield) and its rim
S = 128
shield = [(14, 10), (114, 10), (114, 70), (64, 120), (14, 70)]
def shape(scale=4):
    return [(x * scale, y * scale) for x, y in shield]
big = Image.new("RGBA", (S * 4, S * 4), (0, 0, 0, 0))
ImageDraw.Draw(big).polygon(shape(), fill=(255, 255, 255, 255))
save(big.resize((S, S), Image.LANCZOS), "crest")
big = Image.new("RGBA", (S * 4, S * 4), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.line(shape() + [shape()[0]], fill=GOLD_D, width=26)
d.line(shape() + [shape()[0]], fill=GOLD, width=12)
save(big.resize((S, S), Image.LANCZOS), "crest_rim")

# ---------------------------------------------------------------- menu selection and divider
big = Image.new("RGBA", (1024, 128), (0, 0, 0, 0))
ImageDraw.Draw(big).polygon([(0, 0), (960, 0), (1020, 64), (960, 127), (0, 127)], fill=(255, 255, 255, 255))
save(big.resize((256, 32), Image.LANCZOS), "navsel")
big = Image.new("RGBA", (1024, 64), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.line([(40, 32), (440, 32)], fill=(255, 255, 255, 255), width=4)
d.line([(584, 32), (984, 32)], fill=(255, 255, 255, 255), width=4)
d.polygon([(512, 8), (536, 32), (512, 56), (488, 32)], outline=(255, 255, 255, 255), width=5)
d.polygon([(512, 22), (522, 32), (512, 42), (502, 32)], fill=(255, 255, 255, 255))
for x in (440, 584):
    d.ellipse((x - 6, 26, x + 6, 38), fill=(255, 255, 255, 255))
save(big.resize((256, 16), Image.LANCZOS), "divider")

# ---------------------------------------------------------------- dropdown arrow (white chevron, tinted)
big = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
ImageDraw.Draw(big).line([(18, 40), (64, 88), (110, 40)], fill=(255, 255, 255, 255), width=18, joint="curve")
save(big.resize((32, 32), Image.LANCZOS), "arrow")
