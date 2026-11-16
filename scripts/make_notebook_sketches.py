"""Draw the Adventurer's Notebook ink sketches (original line art) into Media/notebook/sketches/.

Run: python scripts/make_notebook_sketches.py   (needs Pillow)
Each sketch is drawn at 4x with round-capped strokes and scaled down for smooth lines:
128x128, white strokes with alpha, so the addon tints them with the page's ink colour.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "Media" / "notebook" / "sketches"
OUT.mkdir(parents=True, exist_ok=True)
S = 512          # drawing size (4x)
LW = 13          # stroke width at 4x
INK = (255, 255, 255, 255)


def canvas():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def line(d, pts, w=LW):
    d.line(pts, fill=INK, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=INK)


def rect(d, box, r=24, w=LW):
    d.rounded_rectangle(box, radius=r, outline=INK, width=w)


def circle(d, cx, cy, r, w=LW):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=INK, width=w)


def arc(d, box, a0, a1, w=LW):
    d.arc(box, a0, a1, fill=INK, width=w)


def save(im, name):
    im.resize((128, 128), Image.LANCZOS).save(OUT / (name + ".tga"))


def hatch(d, box, step=34, w=6):
    x0, y0, x1, y1 = box
    for k in range(int(x0 - (y1 - y0)), int(x1), step):
        d.line((max(x0, k), y0 + max(0, x0 - k), min(x1, k + (y1 - y0)), y0 + min(y1 - y0, x1 - k)), fill=INK, width=w)


SKETCHES = {}


def sketch(fn):
    SKETCHES[fn.__name__] = fn
    return fn


@sketch
def backpack(d):
    arc(d, (190, 60, 322, 190), 180, 360)
    rect(d, (110, 140, 402, 450), 40)
    line(d, [(110, 250), (402, 250)])
    rect(d, (200, 250, 312, 330), 14)
    rect(d, (140, 330, 220, 430), 14); rect(d, (292, 330, 372, 430), 14)
    line(d, [(150, 170), (150, 240)], 9); line(d, [(362, 170), (362, 240)], 9)


@sketch
def swords(d):
    for flip in (1, -1):
        cx = 256
        a = (cx - 170 * flip, 90); b = (cx + 130 * flip, 390)
        line(d, [a, b])
        line(d, [(a[0] + 12 * flip, a[1] + 26), (b[0] - 30 * flip, b[1] - 50)], 6)
        g0 = (b[0] - 70 * flip, b[1] - 10); g1 = (b[0] - 10 * flip, b[1] - 70)
        line(d, [g0, g1])
        line(d, [b, (b[0] + 45 * flip, b[1] + 45)])
        circle(d, b[0] + 55 * flip, b[1] + 55, 14)


@sketch
def skull(d):
    d.chord((120, 70, 392, 340), 160, 380, outline=INK, width=LW)
    line(d, [(150, 300), (170, 380), (342, 380), (362, 300)])
    circle(d, 200, 230, 36); circle(d, 312, 230, 36)
    line(d, [(256, 270), (238, 310), (274, 310), (256, 270)], 9)
    for x in (210, 256, 302):
        line(d, [(x, 340), (x, 380)], 8)


@sketch
def boot(d):
    line(d, [(200, 70), (200, 330), (120, 380), (110, 430), (400, 430), (400, 390), (320, 360), (320, 70), (200, 70)])
    line(d, [(190, 110), (330, 110)], 9)
    for y in (160, 210, 260):
        line(d, [(230, y), (290, y + 24)], 7); line(d, [(290, y), (230, y + 24)], 7)
    line(d, [(110, 405), (400, 405)], 7)


@sketch
def quill(d):
    line(d, [(110, 430), (380, 90)])
    d.polygon([(380, 90), (420, 70), (330, 230), (300, 190)], outline=INK)
    line(d, [(380, 90), (300, 190), (330, 230), (420, 70), (380, 90)])
    for k in range(5):
        line(d, [(355 - k * 18, 130 + k * 22), (390 - k * 12, 110 + k * 14)], 6)
    rect(d, (300, 350, 420, 440), 20)
    line(d, [(320, 350), (320, 330), (400, 330), (400, 350)], 9)


@sketch
def compass(d):
    circle(d, 256, 256, 180)
    circle(d, 256, 256, 150, 6)
    d.polygon([(256, 110), (284, 256), (256, 402), (228, 256)], outline=INK, width=9)
    hatch(d, (232, 120, 256, 256), 22, 5)
    line(d, [(110, 256), (402, 256)], 7)
    for a in range(0, 360, 45):
        r0, r1 = 160, 180
        x0, y0 = 256 + r0 * math.cos(math.radians(a)), 256 + r0 * math.sin(math.radians(a))
        x1, y1 = 256 + r1 * math.cos(math.radians(a)), 256 + r1 * math.sin(math.radians(a))
        line(d, [(x0, y0), (x1, y1)], 8)


@sketch
def hero(d):
    circle(d, 256, 170, 70)
    arc(d, (130, 230, 382, 520), 180, 360)
    line(d, [(140, 380), (140, 440)]); line(d, [(372, 380), (372, 440)])
    line(d, [(190, 100), (256, 60), (322, 100)], 9)


@sketch
def scales(d):
    line(d, [(256, 80), (256, 420)])
    line(d, [(150, 420), (362, 420)])
    line(d, [(110, 140), (402, 140)])
    for cx in (130, 382):
        line(d, [(cx, 140), (cx - 60, 280)], 7); line(d, [(cx, 140), (cx + 60, 280)], 7)
        arc(d, (cx - 75, 220, cx + 75, 330), 0, 180)
    circle(d, 256, 80, 18)


@sketch
def mugs(d):
    for x in (100, 270):
        rect(d, (x, 170, x + 120, 410), 18)
        arc(d, (x + 90, 220, x + 170, 340), 270, 90)
        arc(d, (x - 10, 120, x + 130, 200), 180, 360, 9)
    line(d, [(230, 120), (250, 90)], 7); line(d, [(260, 120), (280, 90)], 7)


@sketch
def mapscroll(d):
    line(d, [(110, 120), (190, 90), (300, 130), (402, 100), (402, 400), (300, 430), (190, 390), (110, 420), (110, 120)])
    line(d, [(190, 90), (190, 390)], 7); line(d, [(300, 130), (300, 430)], 7)
    pts = [(140, 360), (180, 300), (240, 320), (270, 250)]
    for i in range(0, len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        for t in (0.1, 0.4, 0.7):
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            d.ellipse((p[0] - 7, p[1] - 7, p[0] + 7, p[1] + 7), fill=INK)
    line(d, [(320, 190), (370, 240)]); line(d, [(370, 190), (320, 240)])


@sketch
def tower(d):
    line(d, [(160, 440), (160, 170), (352, 170), (352, 440)])
    for x in (160, 210, 260, 310):
        line(d, [(x, 170), (x, 120), (x + 42, 120), (x + 42, 170)], 9)
    arc(d, (220, 330, 292, 440), 180, 360)
    line(d, [(220, 380), (220, 440)], 9); line(d, [(292, 380), (292, 440)], 9)
    rect(d, (238, 230, 274, 280), 8, 8)
    line(d, [(110, 440), (402, 440)])


@sketch
def campfire(d):
    line(d, [(140, 420), (372, 360)]); line(d, [(140, 360), (372, 420)])
    d.line([(256, 340), (210, 290), (236, 230), (226, 170), (276, 220), (296, 160), (316, 260), (300, 320), (256, 340)], fill=INK, width=LW, joint="curve")
    line(d, [(256, 330), (246, 290), (262, 260), (276, 300), (256, 330)], 8)
    for x, y in ((180, 150), (330, 120), (220, 100)):
        d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=INK)


@sketch
def crown(d):
    line(d, [(110, 380), (130, 170), (200, 280), (256, 130), (312, 280), (382, 170), (402, 380), (110, 380)])
    line(d, [(110, 420), (402, 420)])
    for x, y in ((130, 160), (256, 118), (382, 160)):
        circle(d, x, y, 16, 8)
    circle(d, 256, 330, 20, 8)


@sketch
def hourglass(d):
    line(d, [(140, 90), (372, 90)]); line(d, [(140, 420), (372, 420)])
    line(d, [(170, 90), (170, 130), (256, 255), (170, 380), (170, 420)])
    line(d, [(342, 90), (342, 130), (256, 255), (342, 380), (342, 420)])
    d.polygon([(200, 380), (312, 380), (256, 320)], fill=INK)
    line(d, [(256, 255), (256, 330)], 5)


@sketch
def medal(d):
    line(d, [(190, 70), (230, 250)]); line(d, [(322, 70), (282, 250)])
    line(d, [(190, 70), (322, 70)], 9)
    circle(d, 256, 330, 100)
    circle(d, 256, 330, 70, 6)
    pts = []
    for i in range(10):
        r = 45 if i % 2 == 0 else 20
        a = math.radians(-90 + i * 36)
        pts.append((256 + r * math.cos(a), 330 + r * math.sin(a)))
    pts.append(pts[0])
    line(d, pts, 7)


@sketch
def scroll(d):
    rect(d, (150, 100, 362, 410), 10)
    arc(d, (110, 60, 190, 140), 90, 360); arc(d, (322, 370, 402, 450), 270, 180)
    for y in (160, 200, 240, 280, 320):
        line(d, [(185, y), (325 - (y % 3) * 10, y)], 7)


@sketch
def sunmoon(d):
    circle(d, 190, 210, 70)
    for a in range(0, 360, 40):
        x0, y0 = 190 + 95 * math.cos(math.radians(a)), 210 + 95 * math.sin(math.radians(a))
        x1, y1 = 190 + 125 * math.cos(math.radians(a)), 210 + 125 * math.sin(math.radians(a))
        line(d, [(x0, y0), (x1, y1)], 8)
    arc(d, (250, 240, 420, 410), 60, 300)
    arc(d, (290, 250, 430, 400), 80, 280, 9)


@sketch
def book(d):
    line(d, [(256, 140), (256, 420)])
    line(d, [(256, 140), (140, 110), (90, 120), (90, 400), (140, 390), (256, 420)])
    line(d, [(256, 140), (372, 110), (422, 120), (422, 400), (372, 390), (256, 420)])
    for y in (180, 230, 280, 330):
        line(d, [(120, y), (220, y + 10)], 6); line(d, [(292, y + 10), (392, y)], 6)


@sketch
def magnifier(d):
    circle(d, 220, 220, 110)
    line(d, [(300, 300), (410, 410)], 26)
    arc(d, (150, 150, 290, 290), 200, 260, 8)


for name, fn in SKETCHES.items():
    im, d = canvas()
    fn(d)
    save(im, name)
    print("drew", name)
