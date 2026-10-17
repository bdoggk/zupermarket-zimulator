"""Pictures for the Microsoft Store.

  store/Assets/    the logos inside the Store package (Start menu, taskbar)
  store/listing/   what you upload to the Store page in Partner Center:
                   screenshots, poster art, box art, the tile icon, hero art

They're made from the game icon, the title and screenshots of the game:

  CLEAN=1 SHOT_DIR=/tmp/shots WINDOW=1920x1080 \
    xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tests/showcase.tscn
  python3 tools/make_store_art.py /tmp/shots
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "store" / "Assets"
LISTING = ROOT / "store" / "listing"

# The screenshots for the Store page, in order, and what they're called there.
SCREENSHOTS = [
    ("shopper_card", "1_shoppers"),
    ("computer_desktop", "2_store_computer"),
    ("build_register", "3_build_mode"),
    ("shop_brewery_inside", "4_witch_brewery"),
    ("rival_spy", "5_bone_mart_spy"),
    ("level_up", "6_level_up"),
]
HERO = "store_nohud"  # 16:9 hero art: no HUD, no text
POSTER = "shop_brewery_inside_nohud"
BOX = "store_nohud"


def brain_icon():
    """The game icon at its real 16x16 size (icon.png is drawn 8x)."""
    icon = Image.open(ROOT / "icon.png").convert("RGBA")
    return icon.resize((icon.width // 8, icon.height // 8), Image.NEAREST)


def fit(base, w, h):
    """The icon blown up by whole pixels to fit w x h, with its edges
    stretched out to fill the rest (so its floor and sky reach the sides)."""
    scale = max(1, min(w // base.width, h // base.height))
    art = np.array(base.resize((base.width * scale, base.height * scale), Image.NEAREST))
    top = (h - art.shape[0]) // 2
    left = (w - art.shape[1]) // 2
    pad = ((top, h - art.shape[0] - top), (left, w - art.shape[1] - left), (0, 0))
    return Image.fromarray(np.pad(art, pad, mode="edge"))


def title(scale):
    t = Image.open(ROOT / "assets" / "sprites" / "title.png").convert("RGBA")
    return t.resize((t.width * scale, t.height * scale), Image.NEAREST)


def darken_top(img, height, strength=0.75):
    """A dark fade from the top, so the title reads over the game."""
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shade)
    for y in range(height):
        a = int(255 * strength * (1.0 - y / height))
        d.line([(0, y), (img.width, y)], fill=(8, 10, 12, a))
    return Image.alpha_composite(img, shade)


def crop_scaled(src, w, h, scale, focus_x=0.5):
    """A w x h picture: a (w/scale x h/scale) crop of src, blown up with whole pixels."""
    cw, ch = w // scale, h // scale
    x = int((src.width - cw) * focus_x)
    y = (src.height - ch) // 2
    return src.crop((x, y, x + cw, y + ch)).resize((w, h), Image.NEAREST)


def main():
    shots = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    ASSETS.mkdir(parents=True, exist_ok=True)
    LISTING.mkdir(parents=True, exist_ok=True)

    base = brain_icon()
    fit(base, 50, 50).save(ASSETS / "StoreLogo.png")
    fit(base, 150, 150).save(ASSETS / "Square150x150Logo.png")
    fit(base, 44, 44).save(ASSETS / "Square44x44Logo.png")
    fit(base, 300, 300).save(LISTING / "tile_icon_300x300.png")
    # Wide tile: the brain on the left, its floor running across, the title beside it.
    wide = np.array(fit(base, 150, 150))
    wide = Image.fromarray(np.pad(wide, ((0, 0), (0, 160), (0, 0)), mode="edge"))
    words = title(2)
    wide.alpha_composite(words, (150 + (160 - words.width) // 2, 40))
    wide.save(ASSETS / "Wide310x150Logo.png")

    if shots is None:
        print("No screenshot folder given: made the logos only.")
        return
    for name, out in SCREENSHOTS:
        shutil.copy(shots / f"{name}.png", LISTING / f"screenshot_{out}.png")
    Image.open(shots / f"{HERO}.png").convert("RGB").save(LISTING / "hero_art_1920x1080.png")

    poster = crop_scaled(Image.open(shots / f"{POSTER}.png").convert("RGBA"), 1440, 2160, 2, 0.55)
    poster = darken_top(poster, 1100)
    t = title(18)
    poster.alpha_composite(t, ((1440 - t.width) // 2, 260))
    poster.convert("RGB").save(LISTING / "poster_art_1440x2160.png")

    box = crop_scaled(Image.open(shots / f"{BOX}.png").convert("RGBA"), 2160, 2160, 2, 0.5)
    box = darken_top(box, 1200)
    t = title(26)
    box.alpha_composite(t, ((2160 - t.width) // 2, 300))
    box.convert("RGB").save(LISTING / "box_art_2160x2160.png")
    print("Made", len(list(ASSETS.glob("*.png"))), "logos and", len(list(LISTING.glob("*.png"))), "listing pictures.")


if __name__ == "__main__":
    main()
