"""Draw the hand-made parchment sheet for the Adventurer's Notebook window (original artwork).

Run: python scripts/make_parchment_sheet.py   (needs Pillow)
Writes Media/notebook/sheet.tga (1024x1024 RGBA), stretched over the whole window in game:
aged, mottled paper with torn, deckled edges, a scorched rim, darker corners, and an inked
double frame with corner flourishes.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Media" / "notebook"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(4471)
N = 1024


def noise(cells, blur, size=N):
    small = Image.new("L", (cells, cells))
    small.putdata([random.randint(0, 255) for _ in range(cells * cells)])
    return small.resize((size, size), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))


# ---------------------------------------------------------------- torn outline (alpha mask)
def edge_profile(length, base):
    """Inset along one side: a wandering line with small deckle bumps and a few deep tears."""
    pts, v = [], base
    for i in range(length):
        v += random.uniform(-0.9, 0.9)
        v = max(base - 6, min(base + 8, v))
        pts.append(v + random.uniform(-1.5, 1.5))
    for _ in range(random.randint(5, 8)):  # tears: narrow notches
        c, w, depth = random.randint(40, length - 40), random.randint(6, 18), random.randint(10, 26)
        for i in range(max(0, c - w), min(length, c + w)):
            pts[i] += depth * (1 - abs(i - c) / w)
    return pts

mask = Image.new("L", (N, N), 0)
mpx = mask.load()
top, bottom, left, right = edge_profile(N, 14), edge_profile(N, 14), edge_profile(N, 12), edge_profile(N, 12)
for y in range(N):
    for x in range(N):
        if y >= top[x] and y <= N - 1 - bottom[x] and x >= left[y] and x <= N - 1 - right[y]:
            mpx[x, y] = 255
# rounded, chipped corners
cd = ImageDraw.Draw(mask)
for cx, cy in ((0, 0), (N, 0), (0, N), (N, N)):
    r = random.randint(26, 40)
    cd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=0)
mask = mask.filter(ImageFilter.GaussianBlur(0.8))

# distance-like falloff from the edge, for the scorched rim and darker border
inner = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(5))
ipx = inner.load()

# ---------------------------------------------------------------- paper
coarse, mid, fine = noise(18, 22), noise(72, 4), noise(320, 0.7)
cpx, dpx, fpx = coarse.load(), mid.load(), fine.load()
sheet = Image.new("RGBA", (N, N))
spx = sheet.load()
mpx = mask.load()
for y in range(N):
    for x in range(N):
        k = (cpx[x, y] - 128) * 0.22 + (dpx[x, y] - 128) * 0.10 + (fpx[x, y] - 128) * 0.11
        # lighter, warmer centre; darker towards the edge
        dx, dy = (x - N / 2) / (N / 2), (y - N / 2) / (N / 2)
        vign = (dx * dx + dy * dy) ** 1.1
        k -= vign ** 2.2 * 40 - 6
        rim = 1 - ipx[x, y] / 255.0          # 1 at the torn edge, 0 inside
        k -= rim ** 1.7 * 125
        r, g, b = 220 + k, 198 + k * 0.97, 152 + k * 0.92
        spx[x, y] = (max(0, min(255, int(r))), max(0, min(255, int(g))), max(0, min(255, int(b))), mpx[x, y])

# water stains and specks
st = Image.new("L", (N, N), 0)
sd = ImageDraw.Draw(st)
for _ in range(7):
    cx, cy, r = random.randint(80, N - 80), random.randint(80, N - 80), random.randint(40, 130)
    sd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=random.randint(10, 22))
    sd.ellipse((cx - r, cy - r, cx + r, cy + r), outline=random.randint(26, 40), width=3)
for _ in range(220):
    cx, cy, r = random.randint(0, N), random.randint(0, N), random.uniform(0.6, 2.8)
    sd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=random.randint(50, 130))
# creases: a few long faint fold lines
for _ in range(5):
    x0, y0 = random.randint(0, N), random.choice((0, N))
    x1, y1 = random.randint(0, N), N - y0
    sd.line((x0, y0, x1, y1), fill=22, width=2)
st = st.filter(ImageFilter.GaussianBlur(3))
tpx = st.load()
for y in range(N):
    for x in range(N):
        a = tpx[x, y] / 255.0
        r, g, b, al = spx[x, y]
        spx[x, y] = (int(r * (1 - a * 0.6)), int(g * (1 - a * 0.65)), int(b * (1 - a * 0.75)), al)

# ---------------------------------------------------------------- inked frame and flourishes
ink = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(ink)
INK = (52, 36, 20, 150)
M1, M2 = 40, 48
d.rectangle((M1, M1, N - M1, N - M1), outline=INK, width=3)
d.rectangle((M2, M2, N - M2, N - M2), outline=(52, 36, 20, 110), width=2)


def flourish(cx, cy, sx, sy):
    """A curl in one corner: spiral arc, a leaf and a diamond, mirrored by sx/sy."""
    pts = []
    for i in range(90):
        t = i / 89 * math.pi * 1.8
        r = 44 - i * 0.40
        pts.append((cx + sx * (22 + r * math.cos(t)), cy + sy * (22 + r * math.sin(t))))
    d.line(pts, fill=INK, width=3, joint="curve")
    d.line([(cx + sx * 4, cy + sy * 90), (cx + sx * 4, cy + sy * 170)], fill=INK, width=3)
    d.line([(cx + sx * 90, cy + sy * 4), (cx + sx * 170, cy + sy * 4)], fill=INK, width=3)
    for (px, py) in ((cx + sx * 4, cy + sy * 180), (cx + sx * 180, cy + sy * 4)):
        d.polygon([(px, py - 9), (px + 7, py), (px, py + 9), (px - 7, py)], fill=INK)
    d.ellipse((cx + sx * 58 - 8, cy + sy * 58 - 8, cx + sx * 58 + 8, cy + sy * 58 + 8), outline=INK, width=3)

for cx, cy, sx, sy in ((M1, M1, 1, 1), (N - M1, M1, -1, 1), (M1, N - M1, 1, -1), (N - M1, N - M1, -1, -1)):
    flourish(cx, cy, sx, sy)
ink = ink.filter(ImageFilter.GaussianBlur(0.6))
sheet.alpha_composite(ink)
# keep the torn outline as the final alpha
sheet.putalpha(mask)
sheet.save(OUT / "sheet.tga")
print("wrote", OUT / "sheet.tga")
