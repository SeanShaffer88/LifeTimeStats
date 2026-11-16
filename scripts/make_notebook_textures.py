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


# parchment: warm paper with soft blotches and fine grain
coarse = tileable_noise(512, 24, 3, 0, 255)
fine = tileable_noise(512, 128, 0.6, 0, 255)
paper = Image.new("RGBA", (512, 512))
px = paper.load()
cpx, fpx = coarse.load(), fine.load()
for y in range(512):
    for x in range(512):
        k = (cpx[x, y] - 128) * 0.10 + (fpx[x, y] - 128) * 0.05
        px[x, y] = (int(236 + k), int(226 + k * 0.95), int(200 + k * 0.85), 255)
save(paper, "paper.tga")

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
