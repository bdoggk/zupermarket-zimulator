#!/usr/bin/env python3
"""Draws all the placeholder pixel art for Supermarket Sim and its zombie
twin, Zupermarket Zimulator. It reads which game it's in from
scripts/brand.gd (const ID), so the same script works in both projects.

Run it from the project folder:

    python3 tools/make_sprites.py

Everything is drawn with code, so you can tweak colors and sizes here and
re-run it. You can also replace any PNG in assets/sprites/ with your own art
(e.g. made in Aseprite or Pixelorama) as long as you keep the same size.

Iso conventions used by the game:
  * One floor cell is a 64x32 diamond.
  * Object sprites (walls, shelves, fridges, plants...) are 64 px wide, and
    the center of their floor footprint sits 16 px above the bottom edge.
  * Character sprites are 16x36 and their feet are at (8, 33).
  * Product icons are 8x10.
"""
import math
import random
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"
OUTLINE = (30, 28, 32, 255)


def _brand_id():
    try:
        m = re.search(r'const ID := "(\w+)"', (ROOT / "scripts" / "brand.gd").read_text())
        return m.group(1) if m else "supermarket"
    except OSError:
        return "supermarket"


BRAND = _brand_id()
ZOMBIE = BRAND == "zombie"
BLOOD = (112, 14, 20)
BLOOD_WET = (160, 26, 34)


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
def shade(c, f):
    """Darken (f < 1) or lighten (f > 1) a color."""
    a = c[3] if len(c) == 4 else 255
    return (*[max(0, min(255, int(v * f))) for v in c[:3]], a)


def solid(c):
    return (c[0], c[1], c[2], 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def diamond(cx, cy, hw):
    """Pixels of a 2:1 iso diamond. cx/cy = center, hw = half width (even)."""
    hh = hw // 2
    pts = []
    for r in range(2 * hh):
        span = 2 * (r + 1) if r < hh else 2 * (2 * hh - r)
        y = cy - hh + r
        for x in range(cx - span, cx + span):
            pts.append((x, y))
    return pts


def box_pixels(cx, cy, hw, height):
    """Every pixel of an iso box as (x, y, h, side).

    (cx, cy) is the center of the box's floor footprint. side is "top",
    "left" or "right"; h is the pixel's height above the floor edge (None
    on the top face).
    """
    top = set(diamond(cx, cy - height, hw))
    ymin, ymax = {}, {}
    for x, y in top:
        ymin[x] = min(ymin.get(x, 9999), y)
    for x, y in diamond(cx, cy, hw):
        ymax[x] = max(ymax.get(x, -9999), y)
    for x in ymin:
        for y in range(ymin[x], ymax[x] + 1):
            if (x, y) in top:
                yield x, y, None, "top"
            else:
                yield x, y, ymax[x] - y, ("left" if x < cx else "right")


def prism(img, cx, cy, hw, height, top, left, right, face_fn=None):
    """Draws an iso box. face_fn(x, y, h, side, color) can recolor the side
    faces per pixel; returning None leaves the pixel untouched."""
    px = img.load()
    for x, y, h, side in box_pixels(cx, cy, hw, height):
        if not (0 <= x < img.width and 0 <= y < img.height):
            continue
        if side == "top":
            c = top
        else:
            c = left if side == "left" else right
            if face_fn:
                c = face_fn(x, y, h, side, c)
        if c is not None:
            px[x, y] = solid(c) if len(c) == 3 else c


def outline_object(img, factor=0.55):
    """Darkens the silhouette edge of whatever is drawn in img."""
    px = img.load()
    w, h = img.size
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = shade(px[x, y], factor)


def outline_outside(img, color=OUTLINE):
    """Adds a 1px dark outline around opaque pixels (for characters/icons)."""
    px = img.load()
    w, h = img.size
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255:
                    add.append((x, y))
                    break
    for x, y in add:
        px[x, y] = color


def rect(img, x0, y0, x1, y1, c):
    px = img.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = solid(c)


def dot(img, x, y, c):
    img.load()[x, y] = solid(c)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


# --------------------------------------------------------------------------
# Floors  (you can switch between these in build mode)
# --------------------------------------------------------------------------
FLOOR_STYLES = {
    # id: (main color, alternate color, pattern)
    "beige": ((178, 172, 154), (160, 154, 138), "tile"),
    "blue": ((124, 146, 166), (108, 130, 150), "tile"),
    "wood": ((150, 110, 74), (144, 105, 70), "wood"),
    "mint": ((150, 180, 158), (136, 166, 144), "tile"),
    "slate": ((98, 102, 110), (86, 90, 98), "tile"),
}
if ZOMBIE:
    FLOOR_STYLES = {
        "grimy": ((146, 140, 118), (132, 126, 106), "tile"),
        "morgue": ((148, 166, 170), (134, 152, 158), "tile"),
        "rotten": ((104, 80, 58), (98, 75, 54), "wood"),
        "slime": ((112, 146, 92), (100, 132, 82), "tile"),
        "ash": ((84, 84, 86), (74, 74, 78), "tile"),
    }


def floor_tile(base, seed, stain=False, pattern="tile"):
    random.seed(seed)
    img = new(64, 32)
    px = img.load()
    for x, y in diamond(32, 16, 32):
        c = base
        if pattern == "wood":
            v = math.floor(y - x * 0.5)  # constant along one iso axis
            u = math.floor(y + x * 0.5)
            plank = v // 8
            if v % 8 == 0:
                c = shade(base, 0.74)  # gap between planks
            elif u % 26 == (plank * 9) % 26:
                c = shade(base, 0.82)  # plank end
            elif random.random() < 0.2:
                c = shade(base, random.choice((0.92, 1.06)))
        else:
            n = random.random()
            if n < 0.07:
                c = shade(base, 0.93)
            elif n < 0.11:
                c = shade(base, 1.05)
        px[x, y] = solid(c)
    if stain:  # a grimy blotch, Project Zomboid style (old blood in the zombie game)
        sx, sy = random.randint(22, 40), random.randint(11, 19)
        for x, y in diamond(32, 16, 32):
            d = ((x - sx) / 7.0) ** 2 + ((y - sy) / 3.5) ** 2
            if d < 1.0 and random.random() < 0.85:
                if ZOMBIE:
                    old = px[x, y]
                    px[x, y] = solid(tuple(int(old[i] * 0.55 + (90, 22, 24)[i] * 0.45) for i in range(3)))
                else:
                    px[x, y] = shade(px[x, y], 0.86)
    if ZOMBIE:  # specks of grime and dried blood
        for x, y in diamond(32, 16, 32):
            r = random.random()
            if r < 0.012:
                px[x, y] = solid((96, 24, 26))
            elif r < 0.03:
                px[x, y] = shade(px[x, y], 0.8)
    if pattern == "tile":  # grout line along the two lower edges
        lowest = {}
        for x, y in diamond(32, 16, 32):
            lowest[x] = max(lowest.get(x, -1), y)
        for x, y in lowest.items():
            px[x, y] = shade(base, 0.78)
    return img


def delivery_tile():
    img = floor_tile((128, 126, 120), 99)
    px = img.load()
    inner = set(diamond(32, 16, 26))
    for x, y in diamond(32, 16, 32):
        if (x, y) not in inner:
            stripe = ((x + 2 * y) // 6) % 2 == 0
            px[x, y] = solid((196, 160, 52) if stripe else (44, 42, 40))
    return img


def doormat_tile():
    img = floor_tile((150, 146, 132), 7)
    px = img.load()
    for x, y in diamond(32, 16, 24):
        rib = (x // 2) % 2 == 0
        px[x, y] = solid((64, 58, 54) if rib else (74, 68, 62))
    return img


# --------------------------------------------------------------------------
# Walls  (also switchable in build mode)
# --------------------------------------------------------------------------
WALL_COLORS = {
    "sage": (132, 142, 122),
    "cream": (198, 188, 160),
    "brick": (150, 84, 68),
    "navy": (74, 90, 122),
    "grey": (128, 130, 134),
}
if ZOMBIE:
    WALL_COLORS = {
        "moss": (96, 114, 86),
        "bone": (172, 164, 136),
        "brick": (118, 62, 54),
        "bruise": (92, 74, 102),
        "concrete": (108, 110, 110),
    }
WALL_TOP = (72, 74, 70)
MORTAR = (156, 144, 132)


def wall(height, base, brick=False):
    img = new(64, 32 + height)

    def face(x, y, h, side, c):
        if h < 5:
            return shade(c, 0.62)  # baseboard
        if ZOMBIE:
            streak = (x * 37 + 11) % 13  # grime running down from the top
            if streak < 3 and h > height - (6 + (x * 7) % 22):
                c = shade(c, 0.78)
            if (x * 31 + h * 17) % 97 == 0:
                c = (98, 22, 24)  # a splash of blood
        if brick:
            course = (h - 5) // 5
            if (h - 5) % 5 == 4 or (x + (4 if course % 2 else 0)) % 8 == 0:
                return MORTAR if side == "left" else shade(MORTAR, 0.82)
            return c
        if 30 <= h <= 31:
            return shade(c, 0.88)  # trim line
        return c

    prism(img, 32, img.height - 16, 32, height, WALL_TOP, base, shade(base, 0.82), face)
    outline_object(img, 0.7)
    return img


# --------------------------------------------------------------------------
# Furniture  (all 64 wide, footprint center 16 px above bottom)
# --------------------------------------------------------------------------
SHELF_FRAME = (112, 118, 126)
SHELF_BACK = (58, 62, 70)
SHELF_BOARD = (156, 162, 170)
if ZOMBIE:  # rusty
    SHELF_FRAME = (116, 100, 88)
    SHELF_BACK = (50, 46, 46)
    SHELF_BOARD = (142, 128, 112)
SHELF_HEIGHT = 44
SHELF_LEVELS = (2, 15, 28)  # height of each shelf board above the floor
POSTS = (4, 5, 31, 32, 58, 59)  # x of the corner posts


def shelf_face(x, y, h, side, c):
    for lv in SHELF_LEVELS:
        if lv - 2 <= h <= lv:
            return SHELF_BOARD if h == lv else shade(SHELF_BOARD, 0.8)
    if h >= SHELF_HEIGHT - 2:
        return SHELF_FRAME
    if x in POSTS:
        return SHELF_FRAME if side == "left" else shade(SHELF_FRAME, 0.85)
    return SHELF_BACK if side == "left" else shade(SHELF_BACK, 0.85)


def shelf():
    img = new(64, 32 + SHELF_HEIGHT)
    prism(img, 32, img.height - 16, 28, SHELF_HEIGHT, shade(SHELF_FRAME, 1.1),
          SHELF_BACK, SHELF_BACK, shelf_face)
    outline_object(img)
    return img


FRIDGE_HEIGHT = 48
FRIDGE_BODY = (204, 208, 212)
FRIDGE_INSIDE = (46, 58, 72)
FRIDGE_LIGHT = (150, 214, 240)
GLASS_TINT = (176, 214, 236)
if ZOMBIE:  # the meat cooler: grubby, with a sickly green light
    FRIDGE_BODY = (158, 166, 156)
    FRIDGE_INSIDE = (36, 56, 44)
    FRIDGE_LIGHT = (150, 240, 150)
    GLASS_TINT = (170, 220, 180)


def fridge_face(x, y, h, side, c):
    dark = 0.84 if side == "right" else 1.0
    if h < 2:
        return shade((96, 100, 106), dark)  # kick plate
    if h >= FRIDGE_HEIGHT - 6:
        if h == FRIDGE_HEIGHT - 4:
            return shade(FRIDGE_LIGHT, dark)  # glowing light strip
        return shade(FRIDGE_BODY, dark)
    if x in POSTS:
        return shade(FRIDGE_BODY, dark)
    for lv in SHELF_LEVELS:
        if lv - 1 <= h <= lv:
            return shade((170, 182, 190), dark)  # wire shelf
    return shade(FRIDGE_INSIDE, dark)


def fridge():
    img = new(64, 32 + FRIDGE_HEIGHT)
    prism(img, 32, img.height - 16, 28, FRIDGE_HEIGHT, shade(FRIDGE_BODY, 1.06),
          FRIDGE_BODY, shade(FRIDGE_BODY, 0.84), fridge_face)
    outline_object(img)
    return img


def fridge_glass():
    """Drawn over the items in a fridge, so they look like they're behind glass."""
    img = new(64, 32 + FRIDGE_HEIGHT)

    def glass(x, y, h, side, c):
        if h < 2 or h >= FRIDGE_HEIGHT - 6 or x in POSTS:
            return None
        if (x + h) % 13 in (0, 1):
            return (236, 248, 255, 90)  # glare streak
        return (*GLASS_TINT, 46)

    prism(img, 32, img.height - 16, 28, FRIDGE_HEIGHT, (0, 0, 0, 0), None, None, glass)
    return img


def plant():
    img = new(64, 64)
    cy = img.height - 16
    prism(img, 32, cy, 8, 9, (92, 66, 48), (178, 100, 66), (150, 84, 54))  # pot
    px = img.load()
    random.seed(11)
    greens = [(58, 102, 54), (70, 120, 62), (86, 140, 72), (104, 156, 84)]
    top_y = cy - 9
    blobs = [(-7, -6, 6), (7, -7, 6), (0, -5, 5), (-5, -15, 6), (6, -16, 6),
             (0, -24, 5), (-10, -13, 4), (10, -14, 4), (-2, -30, 3)]
    for bx, by, r in blobs:
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y * 1.4 > r * r or random.random() > 0.93:
                    continue
                X, Y = 32 + bx + x, top_y + by + y
                light = (-(x + y) / (2 * r) + 1) / 2 + random.uniform(-0.25, 0.25)
                c = greens[max(0, min(3, int(light * 4)))]
                px[X, Y] = solid(c)
    outline_object(img, 0.6)
    return img


def gravestone():
    """The zombie game's decoration (it uses the 'plant' slot): a headstone."""
    img = new(64, 64)
    cy = img.height - 16
    prism(img, 32, cy, 12, 4, (92, 96, 88), (78, 82, 76), (64, 68, 62))  # plinth
    px = img.load()
    face, side, rim = (136, 138, 132), (104, 106, 102), (160, 162, 156)
    left, right, bottom, top = 23, 40, cy - 4, cy - 34
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            dy = y - (top + 8)  # round top: a half circle of radius 9
            if dy < 0 and ((x - 31.5) / 9.0) ** 2 + (dy / 8.0) ** 2 > 1:
                continue
            c = side if x >= right - 2 else face
            if dy < 0 and ((x - 31.5) / 9.0) ** 2 + ((dy - 1) / 8.0) ** 2 > 1 and x < right - 2:
                c = rim
            px[x, y] = solid(c)
    for y in range(top + 7, top + 17):  # a cross carved in the front
        dot(img, 30, y, (88, 90, 86))
    for x in range(27, 34):
        dot(img, x, top + 10, (88, 90, 86))
    for x, y in [(26, top + 22), (27, top + 23), (35, top + 20), (34, top + 21)]:
        dot(img, x, y, (96, 98, 94))  # cracks
    random.seed(23)
    for _ in range(30):  # moss
        x, y = random.randint(left, right), random.randint(top + 14, bottom)
        if px[x, y][3] and random.random() < 0.7:
            px[x, y] = solid(random.choice([(86, 112, 70), (104, 128, 80)]))
    for gx in (18, 22, 42, 46):  # tufts of dead grass
        for i in range(3):
            dot(img, gx + i, cy + 2 - (i % 2) * 2, (120, 112, 70))
    outline_object(img, 0.6)
    return img


WOOD_L = (112, 84, 60)
WOOD_R = (92, 68, 48)
LAMINATE = (176, 172, 160)
SCREEN = ((88, 132, 176), (120, 160, 196))
if ZOMBIE:
    WOOD_L = (92, 70, 52)
    WOOD_R = (74, 56, 42)
    LAMINATE = (150, 144, 126)
    SCREEN = ((70, 150, 80), (120, 210, 120))


def register():
    img = new(64, 70)
    cy = img.height - 16
    prism(img, 32, cy, 30, 18, LAMINATE, WOOD_L, WOOD_R)
    prism(img, 34, cy - 18, 10, 9, (84, 86, 92), (62, 64, 70), (50, 52, 58))
    prism(img, 38, cy - 27, 4, 8, (96, 168, 108), (70, 72, 78), (56, 58, 64))
    if ZOMBIE:  # a bloody handprint on the counter
        for x, y in [(20, cy - 14), (21, cy - 14), (22, cy - 13), (20, cy - 12), (21, cy - 11), (24, cy - 15)]:
            dot(img, x, y, BLOOD)
    outline_object(img)
    return img


def computer():
    img = new(64, 72)
    cy = img.height - 16
    prism(img, 32, cy, 26, 16, LAMINATE, WOOD_L, WOOD_R)

    def screen(x, y, h, side, c):
        if side == "left" and 3 <= h <= 11 and x >= 25:
            return SCREEN[0] if h != 7 else SCREEN[1]
        return c

    prism(img, 34, cy - 16, 8, 14, (196, 190, 172), (186, 180, 162), (160, 154, 138), screen)
    outline_object(img)
    return img


CARD_TOP = (196, 156, 102)
CARD_L = (178, 136, 86)
CARD_R = (150, 112, 68)


def stock_box():
    img = new(64, 48)
    cy = img.height - 16
    prism(img, 32, cy, 14, 13, CARD_TOP, CARD_L, CARD_R)
    px = img.load()
    for x, y in diamond(32, cy - 13, 14):  # packing tape
        if abs((x - 32) - 2 * (y - (cy - 13))) <= 1:
            px[x, y] = solid((214, 196, 148))
    if ZOMBIE:  # something has leaked through the cardboard
        for x, y in diamond(26, cy - 6, 6):
            if (x + y) % 3:
                px[x, y] = solid(shade(BLOOD, 1.1))
    outline_object(img)
    return img


def small_box():
    """The box the player holds in front of them while carrying stock."""
    img = new(20, 20)
    prism(img, 10, 13, 8, 7, CARD_TOP, CARD_L, CARD_R)
    outline_object(img)
    return img


# --------------------------------------------------------------------------
# Characters (16x36, feet at 8,33)
# --------------------------------------------------------------------------
def person(skin, hair, shirt, pants, shoes=(48, 40, 36), apron=None, long_hair=False,
           cap=None, vest=None):
    body = new(16, 36)
    rect(body, 5, 24, 7, 31, pants)
    rect(body, 8, 24, 10, 31, shade(pants, 0.82))
    rect(body, 4, 32, 7, 33, shoes)
    rect(body, 8, 32, 11, 33, shade(shoes, 0.85))
    rect(body, 4, 13, 11, 24, shirt)
    rect(body, 10, 13, 11, 24, shade(shirt, 0.82))
    rect(body, 2, 14, 3, 16, shirt)
    rect(body, 12, 14, 13, 16, shade(shirt, 0.82))
    rect(body, 2, 17, 3, 22, skin)
    rect(body, 12, 17, 13, 22, shade(skin, 0.88))
    rect(body, 4, 24, 11, 24, shade(pants, 0.6))  # belt
    if apron:
        rect(body, 5, 15, 10, 26, apron)
        rect(body, 9, 15, 10, 26, shade(apron, 0.85))
        rect(body, 6, 13, 6, 14, apron)
        rect(body, 9, 13, 9, 14, apron)
        rect(body, 6, 21, 9, 21, shade(apron, 0.75))
    rect(body, 7, 11, 8, 12, shade(skin, 0.85))
    rect(body, 5, 3, 10, 10, skin)
    rect(body, 10, 3, 10, 10, shade(skin, 0.9))
    rect(body, 5, 1, 10, 3, hair)
    rect(body, 4, 2, 4, 6, hair)
    rect(body, 11, 2, 11, 5, shade(hair, 0.85))
    rect(body, 5, 4, 6, 4, hair)
    if long_hair:
        rect(body, 4, 2, 4, 12, hair)
        rect(body, 11, 2, 11, 12, shade(hair, 0.85))
    if vest:  # an open work vest with a name tag
        rect(body, 4, 13, 6, 24, vest)
        rect(body, 9, 13, 11, 24, shade(vest, 0.85))
        dot(body, 5, 16, (236, 210, 96))
    if cap:  # a work cap with the brim to one side
        rect(body, 4, 1, 11, 3, cap)
        rect(body, 9, 3, 12, 3, shade(cap, 0.75))
        dot(body, 7, 1, shade(cap, 1.25))
    dot(body, 6, 7, OUTLINE)
    dot(body, 9, 7, OUTLINE)
    outline_outside(body)
    return _with_shadow(body)


def _with_shadow(body):
    img = new(16, 36)
    shadow = img.load()
    for y in range(31, 36):
        for x in range(16):
            if ((x + 0.5 - 8) / 7.5) ** 2 + ((y + 0.5 - 33.5) / 2.2) ** 2 <= 1:
                shadow[x, y] = (0, 0, 0, 70)
    img.alpha_composite(body)
    return img


def zombie(skin, hair, shirt, pants, seed, shoes=(52, 46, 40), apron=None, long_hair=False,
           reaching=True, bald=False, cap=None, vest=None):
    """A zombie. Shoppers reach forward; staff keep their hands to themselves."""
    random.seed(seed)
    body = new(16, 36)
    rect(body, 5, 24, 7, 31, pants)
    rect(body, 8, 24, 10, 31, shade(pants, 0.82))
    if random.random() < 0.6:  # a torn trouser leg
        rect(body, 5, 29, 7, 31, shade(skin, 0.9))
    rect(body, 4, 32, 7, 33, shoes)
    rect(body, 8, 32, 11, 33, shade(shoes, 0.85))
    rect(body, 4, 13, 11, 24, shirt)
    rect(body, 10, 13, 11, 24, shade(shirt, 0.82))
    rect(body, 4, 24, 11, 24, shade(pants, 0.6))
    if apron:
        rect(body, 5, 15, 10, 26, apron)
        rect(body, 9, 15, 10, 26, shade(apron, 0.85))
        rect(body, 6, 13, 6, 14, apron)
        rect(body, 9, 13, 9, 14, apron)
    if vest:
        rect(body, 4, 13, 6, 24, vest)
        rect(body, 9, 13, 11, 24, shade(vest, 0.85))
        dot(body, 5, 16, (200, 180, 90))
    for _ in range(4):  # rips in the clothes
        dot(body, random.randint(5, 10), random.randint(15, 23), shade(skin, 0.75))
    for _ in range(random.randint(3, 6)):  # bloodstains
        dot(body, random.randint(4, 11), random.randint(13, 22), BLOOD)
    if reaching:  # arms stretched out in front
        rect(body, 2, 14, 3, 15, shirt)
        rect(body, 12, 14, 13, 15, shade(shirt, 0.82))
        rect(body, 2, 16, 6, 17, skin)
        rect(body, 9, 16, 13, 17, shade(skin, 0.88))
        dot(body, 6, 17, shade(skin, 0.7))
        dot(body, 9, 17, shade(skin, 0.7))
    else:
        rect(body, 2, 14, 3, 16, shirt)
        rect(body, 12, 14, 13, 16, shade(shirt, 0.82))
        rect(body, 2, 17, 3, 22, skin)
        rect(body, 12, 17, 13, 22, shade(skin, 0.88))
    rect(body, 7, 11, 8, 12, shade(skin, 0.8))
    rect(body, 5, 3, 10, 10, skin)
    rect(body, 10, 3, 10, 10, shade(skin, 0.88))
    dot(body, 5, 8, shade(skin, 0.72))  # rot
    dot(body, 10, 5, shade(skin, 0.72))
    if bald:
        rect(body, 5, 2, 10, 2, shade(skin, 0.95))
        dot(body, 8, 2, (214, 206, 180))  # a bit of skull showing
        dot(body, 9, 3, (214, 206, 180))
    else:
        for x in range(4, 12):  # patchy hair
            for y in range(1, 4):
                if random.random() < 0.75 and not (x in (4, 11) and y == 1):
                    dot(body, x, y, hair if x < 10 else shade(hair, 0.85))
        if long_hair:
            for y in range(2, 13):
                if random.random() < 0.8:
                    dot(body, 4, y, hair)
                if random.random() < 0.8:
                    dot(body, 11, y, shade(hair, 0.85))
    if cap:
        rect(body, 4, 1, 11, 3, cap)
        rect(body, 9, 3, 12, 3, shade(cap, 0.75))
    eye = random.choice([(230, 210, 80), (220, 60, 40), (232, 232, 220)])
    dot(body, 6, 7, eye)
    dot(body, 9, 7, (36, 26, 26) if random.random() < 0.4 else eye)  # sometimes an empty socket
    rect(body, 6, 9, 9, 9, (60, 22, 22))  # mouth
    dot(body, 7, 9, (222, 214, 184))  # a tooth
    dot(body, 8, 10, BLOOD)  # drool
    outline_outside(body)
    return _with_shadow(body)


# --------------------------------------------------------------------------
# Product icons (8x10). Art goes in x 1-6, y 1-8; the outline goes around it.
# --------------------------------------------------------------------------
def icon(draw):
    img = new(8, 10)
    draw(img)
    outline_outside(img)
    return img


def can(label, stripe):
    def d(img):
        rect(img, 1, 1, 6, 8, label)
        rect(img, 5, 1, 6, 8, shade(label, 0.8))
        rect(img, 1, 1, 6, 1, (184, 188, 194))
        rect(img, 1, 8, 6, 8, (150, 154, 160))
        rect(img, 1, 4, 6, 5, stripe)
    return icon(d)


def chips(img):
    rect(img, 1, 2, 6, 8, (214, 176, 58))
    rect(img, 5, 2, 6, 8, (184, 148, 46))
    rect(img, 1, 1, 6, 1, (170, 60, 50))
    rect(img, 2, 4, 5, 6, (176, 62, 52))


def bread(img):
    crust = (186, 124, 64)
    top = (212, 158, 92)
    rect(img, 1, 4, 6, 8, crust)
    rect(img, 2, 3, 5, 3, top)
    rect(img, 1, 4, 6, 4, top)
    rect(img, 6, 4, 6, 8, shade(crust, 0.8))
    rect(img, 1, 8, 6, 8, shade(crust, 0.75))
    dot(img, 2, 5, (230, 196, 136))
    dot(img, 4, 5, (230, 196, 136))


def cereal(img):
    box = (70, 112, 176)
    rect(img, 1, 1, 6, 8, box)
    rect(img, 6, 1, 6, 8, shade(box, 0.8))
    rect(img, 1, 2, 5, 4, (236, 200, 72))
    dot(img, 3, 3, (200, 60, 50))
    rect(img, 2, 6, 4, 7, (240, 236, 220))


def milk(img):
    white = (234, 234, 230)
    blue = (66, 118, 186)
    rect(img, 1, 3, 6, 8, white)
    rect(img, 5, 3, 6, 8, shade(white, 0.84))
    rect(img, 2, 2, 5, 2, shade(white, 0.92))
    rect(img, 3, 1, 4, 1, shade(white, 0.8))
    rect(img, 1, 5, 6, 6, blue)
    rect(img, 5, 5, 6, 6, shade(blue, 0.84))


def apples(img):
    red = (184, 46, 42)
    rect(img, 1, 4, 6, 7, red)
    rect(img, 2, 3, 5, 8, red)
    rect(img, 5, 4, 6, 7, shade(red, 0.8))
    dot(img, 5, 8, shade(red, 0.8))
    dot(img, 2, 4, (232, 124, 112))
    dot(img, 3, 2, (96, 64, 40))
    dot(img, 4, 1, (96, 152, 64))
    dot(img, 5, 2, (96, 152, 64))


def toilet_paper(img):
    w = (238, 238, 242)
    rect(img, 1, 2, 6, 8, w)
    rect(img, 5, 3, 6, 8, shade(w, 0.85))
    rect(img, 1, 1, 6, 2, (252, 252, 254))
    rect(img, 3, 1, 4, 2, (140, 140, 148))
    rect(img, 1, 5, 6, 5, (190, 210, 236))


def pizza(img):
    box = (196, 58, 48)
    rect(img, 1, 4, 6, 8, box)
    rect(img, 1, 4, 6, 4, shade(box, 1.2))
    rect(img, 2, 5, 5, 7, (236, 196, 110))
    dot(img, 3, 6, (176, 50, 40))
    dot(img, 4, 5, (176, 50, 40))
    rect(img, 6, 5, 6, 8, shade(box, 0.8))


def ice_cream(img):
    tub = (240, 206, 218)
    rect(img, 1, 3, 6, 8, tub)
    rect(img, 6, 3, 6, 8, shade(tub, 0.84))
    rect(img, 1, 2, 6, 3, (128, 84, 62))
    rect(img, 2, 5, 4, 6, (150, 214, 226))


def coffee(img):
    bag = (72, 50, 38)
    rect(img, 1, 2, 6, 8, bag)
    rect(img, 6, 2, 6, 8, shade(bag, 0.8))
    rect(img, 2, 1, 5, 1, shade(bag, 1.3))
    rect(img, 2, 4, 5, 6, (214, 184, 136))
    dot(img, 3, 5, (90, 56, 36))
    dot(img, 4, 5, (90, 56, 36))


def batteries(img):
    card = (220, 178, 56)
    rect(img, 1, 1, 6, 8, card)
    rect(img, 6, 1, 6, 8, shade(card, 0.82))
    for bx in (2, 4):
        rect(img, bx, 3, bx + 1, 7, (44, 44, 50))
        rect(img, bx, 3, bx + 1, 3, (200, 128, 60))


# Zombie groceries --------------------------------------------------------
FLESH = (214, 120, 128)
ORGAN = (168, 34, 44)
BONE = (226, 216, 186)


def blood_bottle(img):
    rect(img, 2, 4, 5, 8, (150, 18, 28))  # blood
    rect(img, 5, 4, 5, 8, (108, 12, 20))
    dot(img, 2, 4, (200, 70, 80))  # glint
    rect(img, 3, 2, 4, 3, (170, 40, 50))  # neck
    rect(img, 3, 1, 4, 1, (150, 104, 64))  # cork
    rect(img, 2, 6, 5, 6, (232, 224, 206))  # label


def finger_chips(img):
    bag = (196, 186, 110)
    rect(img, 1, 2, 6, 8, bag)
    rect(img, 5, 2, 6, 8, shade(bag, 0.82))
    rect(img, 1, 1, 6, 1, (150, 30, 36))
    rect(img, 3, 3, 4, 7, (222, 196, 166))  # a finger
    rect(img, 3, 3, 4, 3, (236, 170, 170))  # its nail


def eyeball_jar(img):
    rect(img, 1, 3, 6, 8, (150, 186, 160))  # murky jar
    rect(img, 6, 3, 6, 8, (120, 156, 132))
    rect(img, 1, 1, 6, 2, (120, 122, 128))  # lid
    for ex, ey, iris in [(2, 4, (70, 120, 200)), (4, 6, (90, 160, 80)), (2, 7, (140, 90, 50))]:
        rect(img, ex, ey, ex + 1, ey, (240, 240, 232))
        dot(img, ex + 1, ey, iris)


def lungs(img):
    rect(img, 3, 1, 4, 3, (236, 196, 196))  # windpipe
    dot(img, 2, 3, (236, 196, 196))
    dot(img, 5, 3, (236, 196, 196))
    rect(img, 1, 3, 2, 8, FLESH)  # left lung
    dot(img, 3, 4, FLESH)
    rect(img, 5, 3, 6, 8, shade(FLESH, 0.86))  # right lung
    dot(img, 4, 4, shade(FLESH, 0.86))
    dot(img, 1, 4, (244, 172, 176))
    dot(img, 6, 6, shade(FLESH, 0.7))


def heart(img):
    rect(img, 2, 1, 2, 3, (200, 70, 80))  # arteries
    rect(img, 5, 1, 5, 3, (90, 92, 170))
    rect(img, 1, 3, 6, 6, ORGAN)
    rect(img, 2, 7, 5, 7, ORGAN)
    rect(img, 3, 8, 4, 8, shade(ORGAN, 0.8))
    rect(img, 5, 4, 6, 6, shade(ORGAN, 0.8))
    dot(img, 2, 4, (220, 90, 100))


def kidneys(img):
    k = (138, 48, 48)
    rect(img, 1, 1, 3, 4, k)
    rect(img, 4, 5, 6, 8, shade(k, 0.9))
    dot(img, 3, 2, (0, 0, 0))  # the bean dent
    dot(img, 4, 6, (0, 0, 0))
    dot(img, 1, 1, (180, 80, 80))


def toe_jerky(img):
    pack = (164, 126, 84)
    rect(img, 1, 1, 6, 8, pack)
    rect(img, 6, 1, 6, 8, shade(pack, 0.8))
    rect(img, 2, 3, 5, 6, (236, 220, 196))  # window
    for tx in (2, 3, 4, 5):
        dot(img, tx, 4 + tx % 2, (206, 164, 140))  # toes


def liver(img):
    lv = (110, 30, 40)
    rect(img, 1, 3, 6, 6, lv)
    rect(img, 1, 2, 3, 2, lv)
    rect(img, 2, 7, 5, 7, shade(lv, 0.85))
    dot(img, 2, 3, (160, 60, 70))
    dot(img, 4, 4, (160, 60, 70))


def marrow(img):
    for i in range(6):  # a bone, corner to corner
        dot(img, 1 + i, 7 - i, BONE)
        dot(img, 2 + i if i < 5 else 6, 7 - i, shade(BONE, 0.85))
    for x, y in [(1, 6), (1, 8), (2, 8), (5, 1), (6, 1), (6, 2)]:
        dot(img, x, y, BONE)
    dot(img, 3, 5, (196, 120, 90))  # the good stuff


def brains(img):
    pink = (232, 156, 166)
    fold = (176, 96, 112)
    rect(img, 1, 3, 6, 7, pink)
    rect(img, 2, 2, 5, 2, pink)
    rect(img, 2, 8, 5, 8, shade(pink, 0.85))
    for y in range(2, 9):  # the split down the middle
        dot(img, 3 + (y % 2), y, fold)
    for x, y in [(1, 4), (2, 5), (5, 3), (6, 5), (5, 6), (1, 6)]:
        dot(img, x, y, fold)  # folds
    dot(img, 2, 3, (248, 196, 204))


def spine(img):
    for i, y in enumerate((1, 3, 5, 7)):
        rect(img, 2, y, 5, y, BONE if i % 2 == 0 else shade(BONE, 0.92))
        dot(img, 1, y, shade(BONE, 0.8))
        dot(img, 6, y, shade(BONE, 0.8))
        rect(img, 3, y + 1, 4, y + 1, (200, 110, 110))  # discs
    rect(img, 3, 8, 4, 8, BONE)


def scanner():
    """Handheld barcode scanner icon (12x12), shown in the UI."""
    img = new(12, 12)
    body = (62, 64, 72)
    rect(img, 1, 2, 9, 5, body)
    rect(img, 1, 2, 9, 2, shade(body, 1.35))
    rect(img, 10, 2, 10, 5, (214, 52, 44))
    rect(img, 3, 6, 5, 10, shade(body, 0.85))
    dot(img, 6, 6, (40, 40, 44))
    rect(img, 2, 3, 5, 4, (110, 184, 124))
    outline_outside(img)
    return img


# --------------------------------------------------------------------------
# Title lettering for the main menu (a tiny hand-made 5x7 pixel font)
# --------------------------------------------------------------------------
GLYPHS = {
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


def title_word(word, rows, drips=False):
    """One line of title text: rows = colors from top to bottom of a letter."""
    w = len(word) * 6 - 1
    img = new(w + 4, 7 + 5 + (3 if drips else 0))
    px = img.load()
    for i, ch in enumerate(word):
        for y, line in enumerate(GLYPHS[ch]):
            for x, bit in enumerate(line):
                if bit == "#":
                    X, Y = 2 + i * 6 + x, 1 + y
                    px[X + 1, Y + 2] = solid((70, 34, 30))  # drop shadow
                    px[X, Y + 1] = solid(shade(rows[-1], 0.62))  # bevel under each pixel
    for i, ch in enumerate(word):
        for y, line in enumerate(GLYPHS[ch]):
            for x, bit in enumerate(line):
                if bit == "#":
                    px[2 + i * 6 + x, 1 + y] = solid(rows[y])
    if drips:  # blood dripping off the bottoms of some letters
        random.seed(len(word))
        for i, ch in enumerate(word):
            for x, bit in enumerate(GLYPHS[ch][6]):
                if bit == "#" and random.random() < 0.3:
                    for d in range(random.randint(1, 3)):
                        px[2 + i * 6 + x, 8 + d] = solid(shade(rows[6], 0.85 - d * 0.1))
    outline_outside(img)
    return img


def title():
    if ZOMBIE:
        blood = [(240, 96, 96), (226, 70, 70), (206, 48, 50), (188, 34, 38),
                 (168, 26, 30), (148, 20, 24), (128, 16, 20)]
        toxic = [(214, 250, 150), (190, 240, 120), (168, 226, 100), (148, 210, 86),
                 (128, 192, 74), (110, 172, 64), (92, 150, 56)]
        top = title_word("ZUPERMARKET", blood, drips=True)
        bottom = title_word("ZIMULATOR", toxic)
        img = new(top.width, top.height + bottom.height - 4)
        img.alpha_composite(bottom, ((top.width - bottom.width) // 2, top.height - 4))
        img.alpha_composite(top, (0, 0))
        return img
    gold = [(255, 236, 150), (250, 220, 110), (240, 200, 80), (232, 184, 64),
            (226, 168, 56), (216, 150, 48), (204, 132, 44)]
    green = [(190, 240, 170), (160, 226, 140), (134, 210, 118), (116, 196, 104),
             (100, 180, 92), (86, 162, 82), (72, 144, 72)]
    top = title_word("SUPERMARKET", gold)
    bottom = title_word("SIM", green)
    img = new(top.width, top.height + bottom.height - 2)
    img.alpha_composite(top, (0, 0))
    img.alpha_composite(bottom, ((top.width - bottom.width) // 2, top.height - 2))
    return img


# --------------------------------------------------------------------------
# The OPEN / CLOSED sign by the door (a sandwich board)
# --------------------------------------------------------------------------
SIGN_GLYPHS = {  # 4x5 letters
    "O": [".##.", "#..#", "#..#", "#..#", ".##."],
    "P": ["###.", "#..#", "###.", "#...", "#..."],
    "E": ["####", "#...", "###.", "#...", "####"],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "C": [".###", "#...", "#...", "#...", ".###"],
    "L": ["#...", "#...", "#...", "#...", "####"],
    "S": [".###", "#...", ".##.", "...#", "###."],
    "D": ["###.", "#..#", "#..#", "#..#", "###."],
}


def sign(word, color):
    img = new(64, 56)
    px = img.load()
    for y in range(37, 44):  # soft shadow on the floor
        for x in range(10, 54):
            if ((x - 32) / 21.0) ** 2 + ((y - 40) / 3.2) ** 2 <= 1:
                px[x, y] = (0, 0, 0, 60)
    wood, wood_dark = (128, 90, 58), (96, 66, 42)
    for i in range(10):  # splayed legs
        rect(img, 17 - i // 5, 28 + i, 18 - i // 5, 28 + i, wood_dark)
        rect(img, 45 + i // 5, 28 + i, 46 + i // 5, 28 + i, wood_dark)
    rect(img, 14, 12, 49, 29, wood)  # frame
    rect(img, 14, 29, 49, 29, wood_dark)
    rect(img, 16, 14, 47, 27, (34, 36, 42))  # chalkboard
    rect(img, 29, 9, 34, 11, wood_dark)  # handle
    width = len(word) * 5 - 1
    x0 = 32 - width // 2
    for i, ch in enumerate(word):
        for y, line in enumerate(SIGN_GLYPHS[ch]):
            for x, bit in enumerate(line):
                if bit == "#":
                    dot(img, x0 + i * 5 + x, 18 + y, color)
    for x in range(16, 48, 2):  # little light bulbs along the top
        dot(img, x + 1, 15, shade(color, 0.7))
    outline_object(img, 0.6)
    return img


# --------------------------------------------------------------------------
# Blood spills, the mop bucket and the mop
# --------------------------------------------------------------------------
def spill(seed):
    """A puddle on the floor, centered in a 64x32 floor cell."""
    random.seed(seed)
    img = new(64, 32)
    px = img.load()
    blobs = [(32 + random.randint(-4, 4), 16 + random.randint(-2, 2), random.randint(9, 12))]
    for _ in range(random.randint(2, 4)):
        blobs.append((32 + random.randint(-12, 12), 16 + random.randint(-5, 5), random.randint(4, 8)))
    for y in range(32):
        for x in range(64):
            inside = any(((x - bx) / r) ** 2 + ((y - by) / (r * 0.5)) ** 2 <= 1 for bx, by, r in blobs)
            if inside:
                px[x, y] = (*BLOOD, 225)
    for _ in range(10):  # droplets around it
        x, y = random.randint(8, 56), random.randint(6, 26)
        if px[x, y][3] == 0:
            px[x, y] = (*BLOOD, 210)
    for bx, by, r in blobs[:2]:  # wet shine
        for i in range(max(2, r // 3)):
            if 0 <= bx - r // 3 + i < 64 and 0 <= by - 2 < 32 and px[bx - r // 3 + i, by - 2][3]:
                px[bx - r // 3 + i, by - 2] = (*BLOOD_WET, 235)
    return img


BUCKET = (222, 188, 56)
POLE = (150, 112, 70)
MOP_HEAD = (196, 192, 176)


def mop_bucket(with_mop):
    img = new(64, 72)
    cy = img.height - 16
    prism(img, 32, cy, 12, 13, (70, 74, 80), BUCKET, shade(BUCKET, 0.8))
    prism(img, 38, cy - 13, 4, 5, (150, 154, 160), (120, 124, 130), (100, 104, 110))  # wringer
    px = img.load()
    for x, y in diamond(30, cy - 13, 8):  # dirty water
        if px[x, y][3]:
            px[x, y] = solid((92, 52, 48) if ZOMBIE else (104, 116, 104))
    outline_object(img)
    if with_mop:
        for x in range(22, 33):  # the mop head poking out of the water
            for y in range(cy - 17, cy - 12):
                if (x + y) % 2 == 0 or y == cy - 17:
                    px[x, y] = solid(MOP_HEAD if x < 28 else shade(MOP_HEAD, 0.85))
        for i in range(38):  # the handle, leaning back
            x = 27 + i // 7
            y = cy - 17 - i
            px[x - 1, y] = solid(OUTLINE)
            px[x, y] = solid(shade(POLE, 1.15))
            px[x + 1, y] = solid(POLE)
            px[x + 2, y] = solid(OUTLINE)
    return img


def mop_held():
    """The mop the player carries (12x34, drawn beside them)."""
    img = new(12, 34)
    for y in range(1, 26):
        dot(img, 6, y, POLE)
        dot(img, 7, y, shade(POLE, 0.8))
    rect(img, 4, 25, 9, 26, (120, 124, 130))  # clamp
    for x in range(2, 11):
        for y in range(27, 33):
            if (x + y) % 2 == 0 or y < 29:
                dot(img, x, y, MOP_HEAD if x < 7 else shade(MOP_HEAD, 0.85))
    outline_outside(img)
    return img


def app_icon(beans):
    bg = new(64, 64)
    rect(bg, 0, 0, 63, 63, (30, 40, 32) if ZOMBIE else (38, 42, 50))
    rect(bg, 0, 44, 63, 63, (44, 56, 44) if ZOMBIE else (52, 56, 64))
    big = beans.resize((40, 50), Image.NEAREST)
    bg.alpha_composite(big, (12, 6))
    return bg.resize((128, 128), Image.NEAREST)


def main():
    for i, (style, (a, b, pattern)) in enumerate(FLOOR_STYLES.items()):
        save(floor_tile(a, 10 * i + 1, pattern=pattern), f"floor_{style}_a")
        save(floor_tile(b, 10 * i + 2, pattern=pattern), f"floor_{style}_b")
        save(floor_tile(a, 10 * i + 3, stain=True, pattern=pattern), f"floor_{style}_stain")
    save(delivery_tile(), "floor_delivery")
    save(doormat_tile(), "floor_doormat")
    for name, color in WALL_COLORS.items():
        save(wall(56, color, brick=name == "brick"), f"wall_{name}_tall")
        save(wall(10, color, brick=name == "brick"), f"wall_{name}_low")
        tall = wall(56, color, brick=name == "brick")
        save(tall.crop((2, 34, 30, 58)), f"wall_{name}_swatch")  # for the paint menu

    save(shelf(), "shelf")
    save(fridge(), "fridge")
    save(fridge_glass(), "fridge_glass")
    save(gravestone() if ZOMBIE else plant(), "plant")
    save(register(), "register")
    save(computer(), "computer")
    save(stock_box(), "box")
    save(small_box(), "box_small")
    for i in range(3):
        save(spill(40 + i), f"spill_{i}")
    save(mop_bucket(True), "mop_bucket")
    save(mop_bucket(False), "mop_bucket_empty")
    save(mop_held(), "mop_held")

    if ZOMBIE:
        save(zombie((150, 176, 130), (70, 50, 30), (80, 92, 110), (60, 60, 66), seed=1,
                    apron=(124, 42, 38), reaching=False), "player")
        shoppers = [
            dict(skin=(140, 170, 120), hair=(50, 40, 30), shirt=(122, 112, 90), pants=(70, 80, 100)),
            dict(skin=(150, 152, 132), hair=(30, 26, 24), shirt=(140, 60, 60), pants=(80, 60, 60), long_hair=True),
            dict(skin=(120, 150, 110), hair=(0, 0, 0), shirt=(90, 100, 124), pants=(50, 50, 56), bald=True),
            dict(skin=(164, 172, 142), hair=(180, 160, 90), shirt=(100, 122, 90), pants=(60, 60, 70), long_hair=True),
            dict(skin=(112, 132, 100), hair=(110, 46, 34), shirt=(112, 92, 132), pants=(80, 70, 56)),
            dict(skin=(140, 142, 152), hair=(124, 124, 124), shirt=(196, 198, 188), pants=(176, 178, 168)),
        ]
        for i, z in enumerate(shoppers):
            save(zombie(seed=10 + i, **z), f"customer_{i}")
        save(zombie((132, 162, 120), (60, 46, 32), (110, 110, 104), (66, 70, 78), seed=31,
                    reaching=False, cap=(196, 112, 40)), "staff_stocker")
        save(zombie((162, 162, 140), (40, 34, 30), (198, 196, 186), (54, 54, 60), seed=32,
                    reaching=False, vest=(124, 30, 40), long_hair=True), "staff_cashier")
        icons = [("guts", None), ("blood", blood_bottle), ("fingers", finger_chips),
                 ("eyeballs", eyeball_jar), ("lungs", lungs), ("hearts", heart),
                 ("kidneys", kidneys), ("toes", toe_jerky), ("liver", liver),
                 ("marrow", marrow), ("brains", brains), ("spine", spine)]
        for name, draw in icons:
            save(can((132, 52, 64), (214, 140, 150)) if draw is None else icon(draw), f"item_{name}")
        hero = icon(brains)
        sign_open = (150, 232, 110)
    else:
        save(person((224, 182, 142), (92, 62, 40), (70, 88, 128), (58, 58, 68),
                    apron=(148, 62, 52)), "player")
        customers = [
            ((236, 196, 160), (60, 44, 32), (120, 132, 88), (70, 84, 112), False),
            ((168, 118, 82), (30, 26, 24), (150, 90, 80), (90, 80, 70), False),
            ((214, 168, 128), (196, 168, 96), (96, 110, 136), (60, 60, 64), True),
            ((120, 84, 60), (28, 24, 22), (178, 158, 100), (64, 72, 96), True),
            ((240, 206, 176), (150, 70, 40), (110, 96, 130), (80, 70, 56), True),
            ((196, 150, 110), (90, 90, 90), (130, 72, 72), (96, 96, 100), False),
        ]
        for i, (skin, hair, shirt, pants, long_hair) in enumerate(customers):
            save(person(skin, hair, shirt, pants, long_hair=long_hair), f"customer_{i}")
        save(person((206, 160, 120), (54, 40, 30), (78, 124, 82), (150, 130, 96),
                    cap=(66, 112, 70)), "staff_stocker")
        save(person((232, 196, 166), (120, 70, 40), (228, 226, 218), (54, 54, 62),
                    vest=(56, 92, 150), long_hair=True), "staff_cashier")
        hero = can((176, 108, 56), (222, 210, 180))
        save(hero, "item_beans")
        save(can((168, 52, 48), (220, 220, 224)), "item_soda")
        for name, draw in [("chips", chips), ("bread", bread), ("cereal", cereal),
                           ("milk", milk), ("apples", apples), ("toilet_paper", toilet_paper),
                           ("pizza", pizza), ("ice_cream", ice_cream), ("coffee", coffee),
                           ("batteries", batteries)]:
            save(icon(draw), f"item_{name}")
        sign_open = (120, 230, 120)
    save(scanner(), "scanner")
    save(title(), "title")
    save(sign("OPEN", sign_open), "sign_open")
    save(sign("CLOSED", (230, 86, 74)), "sign_closed")

    app_icon(hero).save(ROOT / "icon.png")
    print(f"Sprites for '{BRAND}' written to", OUT)


if __name__ == "__main__":
    main()
