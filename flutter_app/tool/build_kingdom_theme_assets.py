#!/usr/bin/env python3
"""Build the four WILDCARD kingdom cosmetic asset packs.

The script preserves the shipping environments and Sly artwork, then derives:
* uncluttered 1080x1920 gameplay backgrounds,
* 1024x1024 suit-specific felt textures,
* strict 3x3 expression atlases and 2x2 action atlases.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art"
BACKGROUNDS = ART / "backgrounds"
SLY = ART / "sly"
TABLES = ROOT / "assets" / "tables"


PACKS = {
    "hearts": {
        "home": BACKGROUNDS / "wildcard-theme-ember-casino.webp",
        "game": BACKGROUNDS / "wildcard-kingdom-hearts-gameplay.webp",
        "table": TABLES / "kingdom_hearts_felt.webp",
        "sly": SLY / "sly-hearts-expression-grid.webp",
        "stage": SLY / "sly-hearts-stage-actions-grid.webp",
        "crop_y": 620,
        "primary": "#7A2435",
        "secondary": "#D79064",
        "accent": "#FF846D",
        "ink": "#120609",
    },
    "spades": {
        "home": BACKGROUNDS / "wildcard-theme-moonlit-masquerade.webp",
        "game": BACKGROUNDS / "wildcard-kingdom-spades-gameplay.webp",
        "table": TABLES / "kingdom_spades_felt.webp",
        "sly": SLY / "sly-spades-expression-grid.webp",
        "stage": SLY / "sly-spades-stage-actions-grid.webp",
        "crop_y": 650,
        "primary": "#172A46",
        "secondary": "#8091A7",
        "accent": "#9EDCFF",
        "ink": "#070A12",
    },
    "diamonds": {
        "home": BACKGROUNDS / "wildcard-theme-clockwork-royale.webp",
        "game": BACKGROUNDS / "wildcard-kingdom-diamonds-gameplay.webp",
        "table": TABLES / "kingdom_diamonds_felt.webp",
        "sly": SLY / "sly-diamonds-expression-grid.webp",
        "stage": SLY / "sly-diamonds-stage-actions-grid.webp",
        "crop_y": 820,
        "primary": "#20505A",
        "secondary": "#D68B2B",
        "accent": "#45E0C6",
        "ink": "#0D0A10",
    },
    "clubs": {
        "home": BACKGROUNDS / "wildcard-theme-emerald-throne.webp",
        "game": BACKGROUNDS / "wildcard-kingdom-clubs-gameplay.webp",
        "table": TABLES / "kingdom_clubs_felt.webp",
        "sly": SLY / "sly-clubs-expression-grid.webp",
        "stage": SLY / "sly-clubs-stage-actions-grid.webp",
        "crop_y": 820,
        "primary": "#146A4A",
        "secondary": "#86643C",
        "accent": "#45E0C6",
        "ink": "#06120E",
    },
}


def rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def rgba(value: str, alpha: int) -> tuple[int, int, int, int]:
    return (*rgb(value), alpha)


def draw_suit(
    draw: ImageDraw.ImageDraw,
    center: tuple[int, int],
    suit: str,
    size: int,
    fill: tuple[int, int, int, int],
    edge: tuple[int, int, int, int],
) -> None:
    cx, cy = center
    r = size / 2
    width = max(2, size // 26)
    if suit == "hearts":
        draw.ellipse((cx - r * .72, cy - r * .52, cx - r * .04, cy + r * .16), fill=fill, outline=edge, width=width)
        draw.ellipse((cx + r * .04, cy - r * .52, cx + r * .72, cy + r * .16), fill=fill, outline=edge, width=width)
        pts = [(cx - r * .72, cy - r * .04), (cx + r * .72, cy - r * .04), (cx, cy + r * .82)]
        draw.polygon(pts, fill=fill)
        draw.line(pts + [pts[0]], fill=edge, width=width, joint="curve")
    elif suit == "diamonds":
        pts = [(cx, cy - r * .86), (cx + r * .68, cy), (cx, cy + r * .86), (cx - r * .68, cy)]
        draw.polygon(pts, fill=fill)
        draw.line(pts + [pts[0]], fill=edge, width=width, joint="curve")
    elif suit == "clubs":
        cr = r * .34
        for ox, oy in [(cx, cy - r * .35), (cx - r * .36, cy + r * .02), (cx + r * .36, cy + r * .02)]:
            draw.ellipse((ox - cr, oy - cr, ox + cr, oy + cr), fill=fill, outline=edge, width=width)
        pts = [(cx - r * .15, cy + r * .15), (cx + r * .15, cy + r * .15), (cx + r * .32, cy + r * .72), (cx - r * .32, cy + r * .72)]
        draw.polygon(pts, fill=fill)
        draw.line(pts + [pts[0]], fill=edge, width=width, joint="curve")
    else:
        cr = r * .33
        draw.ellipse((cx - r * .70, cy - r * .02, cx - r * .04, cy + r * .64), fill=fill, outline=edge, width=width)
        draw.ellipse((cx + r * .04, cy - r * .02, cx + r * .70, cy + r * .64), fill=fill, outline=edge, width=width)
        upper = [(cx, cy - r * .86), (cx - r * .70, cy + r * .22), (cx + r * .70, cy + r * .22)]
        draw.polygon(upper, fill=fill)
        draw.line(upper + [upper[0]], fill=edge, width=width, joint="curve")
        stem = [(cx - r * .13, cy + r * .28), (cx + r * .13, cy + r * .28), (cx + r * .30, cy + r * .76), (cx - r * .30, cy + r * .76)]
        draw.polygon(stem, fill=fill)
        draw.line(stem + [stem[0]], fill=edge, width=width, joint="curve")


def hue_mask(image: Image.Image, low: int, high: int, saturation_floor: int = 50) -> Image.Image:
    hsv = image.convert("RGB").convert("HSV")
    hue, saturation, _ = hsv.split()
    hue_mask_image = hue.point(lambda p: 255 if low <= p <= high else 0)
    saturation_mask = saturation.point(lambda p: 255 if p >= saturation_floor else 0)
    mask = ImageChops.multiply(hue_mask_image, saturation_mask)
    if "A" in image.getbands():
        mask = ImageChops.multiply(mask, image.getchannel("A"))
    return mask.filter(ImageFilter.GaussianBlur(1.2))


def recolor_group(image: Image.Image, mask: Image.Image, dark: str, light: str) -> Image.Image:
    luminance = ImageOps.grayscale(image.convert("RGB"))
    coloured = ImageOps.colorize(luminance, black=rgb(dark), white=rgb(light)).convert("RGBA")
    coloured.putalpha(image.getchannel("A") if "A" in image.getbands() else 255)
    return Image.composite(coloured, image, mask)


def recolor_sly(source: Image.Image, pack: dict[str, object]) -> Image.Image:
    source = source.convert("RGBA")
    original_alpha = source.getchannel("A")
    # Shipping Sly is dominated by violet and teal; transform only those
    # saturated costume regions so skin, eyes, gold trim and expression remain.
    purple = hue_mask(source, 176, 226, 42)
    teal = hue_mask(source, 92, 150, 42)
    result = recolor_group(source, purple, str(pack["ink"]), str(pack["primary"]))
    result = recolor_group(result, teal, str(pack["primary"]), str(pack["secondary"]))
    result.putalpha(original_alpha)
    return result


def build_sly_assets(suit: str, pack: dict[str, object]) -> None:
    expression_source = Image.open(SLY / "sly-expression-grid.webp").convert("RGBA")
    recolored = recolor_sly(expression_source, pack)
    recolored = recolored.resize((1200, 1200), Image.Resampling.LANCZOS)
    rd = ImageDraw.Draw(recolored, "RGBA")
    for row in range(3):
        for col in range(3):
            draw_suit(
                rd,
                (col * 400 + 355, row * 400 + 347),
                suit,
                54,
                rgba(str(pack["accent"]), 226),
                (7, 8, 16, 235),
            )
    Path(pack["sly"]).parent.mkdir(parents=True, exist_ok=True)
    recolored.save(pack["sly"], "WEBP", quality=95, method=6)

    stage_source = Image.open(SLY / "sly-stage-actions-grid.webp").convert("RGBA")
    stage = recolor_sly(stage_source, pack)
    sd = ImageDraw.Draw(stage, "RGBA")
    for row in range(2):
        for col in range(2):
            draw_suit(
                sd,
                (col * 768 + 710, row * 768 + 705),
                suit,
                86,
                rgba(str(pack["accent"]), 225),
                (7, 8, 16, 235),
            )
    stage.save(pack["stage"], "WEBP", quality=95, method=6)


def build_gameplay_background(suit: str, pack: dict[str, object]) -> None:
    source = Image.open(pack["home"]).convert("RGB")
    crop_y = int(pack["crop_y"])
    environment = source.crop((0, crop_y, source.width, source.height))
    background = ImageOps.fit(
        environment,
        (1080, 1920),
        Image.Resampling.LANCZOS,
        centering=(0.5, 0.52),
    ).convert("RGBA")
    background = ImageEnhance.Color(background).enhance(.90)
    background = ImageEnhance.Contrast(background).enhance(1.06)

    overlay = Image.new("RGBA", background.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    for y in range(1920):
        top_alpha = int(105 * max(0.0, 1.0 - y / 650))
        bottom_alpha = int(95 * max(0.0, (y - 1240) / 680))
        alpha = min(135, top_alpha + bottom_alpha + 18)
        draw.line((0, y, 1080, y), fill=(*rgb(str(pack["ink"])), alpha), width=1)
    # Quiet edge motifs remain visible without competing with cards/equations.
    draw_suit(draw, (108, 305), suit, 122, rgba(str(pack["accent"]), 54), rgba(str(pack["ink"]), 75))
    draw_suit(draw, (972, 305), suit, 122, rgba(str(pack["accent"]), 54), rgba(str(pack["ink"]), 75))
    draw_suit(draw, (90, 1610), suit, 150, rgba(str(pack["secondary"]), 44), rgba(str(pack["ink"]), 70))
    draw_suit(draw, (990, 1610), suit, 150, rgba(str(pack["secondary"]), 44), rgba(str(pack["ink"]), 70))
    background = Image.alpha_composite(background, overlay)
    background.convert("RGB").save(pack["game"], "WEBP", quality=92, method=6)


def build_table(suit: str, pack: dict[str, object]) -> None:
    size = 1024
    base = Image.new("RGB", (size, size), rgb(str(pack["ink"])))
    noise = Image.effect_noise((size, size), 10).convert("L")
    cloth = ImageOps.colorize(noise, rgb(str(pack["ink"])), rgb(str(pack["primary"]))).convert("RGBA")
    cloth.putalpha(150)
    table = Image.alpha_composite(base.convert("RGBA"), cloth)
    draw = ImageDraw.Draw(table, "RGBA")
    primary = str(pack["primary"])
    secondary = str(pack["secondary"])
    accent = str(pack["accent"])
    # Seam-safe 256px lattice; lines meet identically at opposite edges.
    for offset in range(-1024, 2049, 256):
        draw.line((offset, 0, offset + 1024, 1024), fill=rgba(secondary, 25), width=5)
        draw.line((offset, 1024, offset + 1024, 0), fill=rgba(accent, 19), width=3)
    for x in range(0, 1025, 256):
        draw.line((x, 0, x, 1024), fill=rgba(primary, 28), width=2)
    for y in range(0, 1025, 256):
        draw.line((0, y, 1024, y), fill=rgba(primary, 28), width=2)

    for cx, cy, motif_size, alpha in [
        (512, 512, 420, 46),
        (128, 128, 105, 70),
        (896, 128, 105, 70),
        (128, 896, 105, 70),
        (896, 896, 105, 70),
    ]:
        draw_suit(draw, (cx, cy), suit, motif_size, rgba(accent, alpha), rgba(secondary, min(110, alpha + 30)))
    draw.rounded_rectangle((52, 52, 972, 972), radius=76, outline=rgba(secondary, 78), width=8)
    draw.rounded_rectangle((76, 76, 948, 948), radius=60, outline=rgba(accent, 42), width=3)
    table.convert("RGB").save(pack["table"], "WEBP", quality=94, method=6)


def validate() -> None:
    expected = []
    for pack in PACKS.values():
        expected.extend([pack["game"], pack["table"], pack["sly"], pack["stage"]])
    specs = {
        "gameplay": (1080, 1920),
        "felt": (1024, 1024),
        "expression": (1200, 1200),
        "actions": (1536, 1536),
    }
    for path in expected:
        path = Path(path)
        if not path.is_file():
            raise FileNotFoundError(path)
        with Image.open(path) as image:
            if "gameplay" in path.name:
                expected_size = specs["gameplay"]
            elif "felt" in path.name:
                expected_size = specs["felt"]
            elif "expression" in path.name:
                expected_size = specs["expression"]
            elif "actions" in path.name:
                expected_size = specs["actions"]
            else:
                raise ValueError(f"Unknown generated asset kind: {path}")
            if image.size != expected_size:
                raise ValueError(f"{path}: expected {expected_size}, found {image.size}")
            image.verify()
        print(f"[asset] {path.relative_to(ROOT)}")


def main() -> None:
    for suit, pack in PACKS.items():
        build_gameplay_background(suit, pack)
        build_table(suit, pack)
        build_sly_assets(suit, pack)
    validate()


if __name__ == "__main__":
    main()
