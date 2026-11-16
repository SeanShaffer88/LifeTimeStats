"""Generate the Adventurer's Notebook skin textures (original artwork) into Media/notebook/.

Run: python scripts/make_notebook_textures.py   (needs Pillow)
All textures are power-of-two, 32-bit TGA. Shapes are white with alpha so the addon tints them.
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Media" / "notebook"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(1120)


def tileable_noise(size, cells, blur, lo, hi):
    """Seamless noise: random grid tiled 3x3, blurred, centre cut out, scaled up."""
    small = Image.new("L", (cells, cells))
    small.putdata([random.randint(lo, hi) for _ in range(cells * cells)])
    big = Image.new("L", (cells * 3, cells * 3))
    for x in range(3):
        for y in range(3):
            big.paste(small, (x * cells, y * cells))
    big = big.resize((cells * 3 * 4, cells * 3 * 4), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))
    c = cells * 4
    return big.crop((c, c, c * 2, c * 2)).resize((size, size), Image.BICUBIC)


def save(img, name):
    img.save(OUT / name)
    print("wrote", OUT / name, img.size)


# parchment: aged and weathered - darker tan, mottled blotches, tide-mark stains and fibres
coarse = tileable_noise(512, 20, 3, 0, 255)
mid = tileable_noise(512, 48, 1.5, 0, 255)
fine = tileable_noise(512, 160, 0.5, 0, 255)
paper = Image.new("RGBA", (512, 512))
px = paper.load()
cpx, mpx, fpx = coarse.load(), mid.load(), fine.load()
for y in range(512):
    for x in range(512):
        k = (cpx[x, y] - 128) * 0.26 + (mpx[x, y] - 128) * 0.12 + (fpx[x, y] - 128) * 0.09
        px[x, y] = (max(0, min(255, int(214 + k))), max(0, min(255, int(192 + k * 0.95))), max(0, min(255, int(146 + k * 0.85))), 255)
# tide-mark stains and darker spots, drawn with wrap-around so the tile stays seamless
stains = Image.new("L", (512, 512), 0)
sd = ImageDraw.Draw(stains)
for _ in range(4):
    cx, cy, r = random.randint(0, 511), random.randint(0, 511), random.randint(18, 70)
    for ox in (-512, 0, 512):
        for oy in (-512, 0, 512):
            sd.ellipse((cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r), outline=38, width=2)
            sd.ellipse((cx + ox - r + 6, cy + oy - r + 6, cx + ox + r - 6, cy + oy + r - 6), fill=10)
for _ in range(60):
    cx, cy, r = random.randint(0, 511), random.randint(0, 511), random.randint(1, 4)
    for ox in (-512, 0, 512):
        for oy in (-512, 0, 512):
            sd.ellipse((cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r), fill=random.randint(40, 110))
# paper fibres: short faint strokes
for _ in range(500):
    x0, y0 = random.randint(0, 511), random.randint(0, 511)
    dx, dy = random.randint(-14, 14), random.randint(-5, 5)
    for ox in (-512, 0, 512):
        for oy in (-512, 0, 512):
            sd.line((x0 + ox, y0 + oy, x0 + ox + dx, y0 + oy + dy), fill=random.randint(14, 34), width=1)
stains = stains.filter(ImageFilter.GaussianBlur(2.2))
spx = stains.load()
for y in range(512):
    for x in range(512):
        a = spx[x, y] / 255.0
        r, g, b, _ = px[x, y]
        px[x, y] = (int(r * (1 - a * 0.55)), int(g * (1 - a * 0.6)), int(b * (1 - a * 0.7)), 255)
save(paper, "paper.tga")

# age: stretched over each page - edges browned and worn, darker towards the corners
age = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
apx = age.load()
wear = tileable_noise(512, 40, 2, 0, 255).load()
for y in range(512):
    for x in range(512):
        dx = min(x, 511 - x) / 256.0
        dy = min(y, 511 - y) / 256.0
        edge = 1 - min(dx, dy) * 3.2 + (wear[x, y] - 128) / 640.0
        corner = (1 - dx) * (1 - dy)
        a = max(0.0, min(1.0, edge)) ** 2.2 * 0.85 + corner ** 6 * 0.35
        apx[x, y] = (72, 44, 18, int(max(0, min(1, a)) * 255))
save(age, "age.tga")

# wood: dark planks with vertical grain
grain = tileable_noise(256, 64, 0.8, 0, 255).resize((256, 256))
wood = Image.new("RGBA", (256, 256))
wpx, gpx = wood.load(), grain.load()
for y in range(256):
    for x in range(256):
        g = gpx[(x * 4) % 256, y // 4] if False else gpx[x, (y // 6) % 256]
        k = (g - 128) * 0.18
        seam = -18 if x % 64 in (0, 1) else 0
        wpx[x, y] = (max(0, int(74 + k + seam)), max(0, int(51 + k * 0.8 + seam)), max(0, int(34 + k * 0.6 + seam)), 255)
save(wood, "wood.tga")

# spiral ring: a metal loop seen from the side (64x32), coloured in
ring = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(ring)
d.rounded_rectangle((4, 9, 60, 23), radius=7, fill=(35, 32, 28, 255))
for i, shade in enumerate((110, 160, 220, 240, 200, 150, 105)):
    d.line((10, 11 + i, 54, 11 + i), fill=(shade, shade, shade, 255))
d.ellipse((2, 12, 12, 20), fill=(20, 18, 16, 230))
save(ring, "ring.tga")

# tab: rounded on the left, flat on the right (white, tinted in game)
tab = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
d = ImageDraw.Draw(tab)
d.rounded_rectangle((0, 0, 80, 127), radius=14, fill=(255, 255, 255, 255))
save(tab, "tab.tga")

# tag: a label with pointed ends (white, tinted in game)
tag = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(tag)
d.polygon([(10, 1), (117, 1), (127, 16), (117, 30), (10, 30), (0, 16)], fill=(255, 255, 255, 255))
save(tag, "tag.tga")
tagline = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(tagline)
d.polygon([(10, 1), (117, 1), (127, 16), (117, 30), (10, 30), (0, 16)], outline=(255, 255, 255, 255), width=2)
save(tagline, "tagline.tga")

# crease: the soft shadow where two pages meet (horizontal gradient, darkest in the middle)
crease = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
cp = crease.load()
for x in range(64):
    a = int(110 * max(0.0, 1 - abs(x - 31.5) / 32) ** 2.2)
    for y in range(16):
        cp[x, y] = (60, 40, 15, a)
save(crease, "crease.tga")

# wax seal (for achievements and goals reached), tinted in game
seal = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
d = ImageDraw.Draw(seal)
pts = []
import math
for i in range(24):
    r = 30 if i % 2 == 0 else 26
    a = math.pi * 2 * i / 24
    pts.append((32 + r * math.cos(a), 32 + r * math.sin(a)))
d.polygon(pts, fill=(255, 255, 255, 255))
d.ellipse((14, 14, 50, 50), outline=(200, 200, 200, 255), width=2)
save(seal, "seal.tga")
