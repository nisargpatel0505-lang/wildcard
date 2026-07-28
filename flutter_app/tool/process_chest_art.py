"""Build runtime Royal Vault assets from generated chroma-key component sheets.

The high-resolution source sheets stay under assets/art/masters/chests, which
is intentionally outside the Flutter asset manifest. Runtime files are trimmed,
downscaled where useful, and encoded as high-quality WebP files with alpha.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


APP_ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = APP_ROOT / "assets" / "art" / "masters" / "chests"
OUTPUT_DIR = APP_ROOT / "assets" / "art" / "chests"

COMPONENTS = {
    "body": (0, 0),
    "lid": (1, 0),
    "lock": (0, 1),
    "crest": (1, 1),
}


def _trim_with_padding(image: Image.Image, padding: int = 12) -> Image.Image:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("Component quadrant contains no visible pixels")
    left, top, right, bottom = bounds
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def _save_runtime(image: Image.Image, destination: Path, max_edge: int) -> None:
    scale = min(1.0, max_edge / max(image.size))
    if scale < 1.0:
        image = image.resize(
            (round(image.width * scale), round(image.height * scale)),
            Image.Resampling.LANCZOS,
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, "WEBP", quality=90, method=6, exact=True)


def build_components(tier: str) -> None:
    source = MASTER_DIR / f"wildcard-{tier}-vault-components-alpha.png"
    sheet = Image.open(source).convert("RGBA")
    half_width = sheet.width // 2
    half_height = sheet.height // 2
    for name, (column, row) in COMPONENTS.items():
        quadrant = sheet.crop(
            (
                column * half_width,
                row * half_height,
                sheet.width if column else half_width,
                sheet.height if row else half_height,
            )
        )
        component = _trim_with_padding(quadrant)
        max_edge = 720 if name in {"body", "lid"} else 420
        _save_runtime(
            component,
            OUTPUT_DIR / f"wildcard-{tier}-vault-{name}.webp",
            max_edge,
        )


def build_room() -> None:
    source = MASTER_DIR / "wildcard-sly-vault-room-master.png"
    room = Image.open(source).convert("RGB")
    max_width = 1080
    if room.width > max_width:
        scale = max_width / room.width
        room = room.resize(
            (max_width, round(room.height * scale)),
            Image.Resampling.LANCZOS,
        )
    room.save(
        OUTPUT_DIR / "wildcard-sly-vault-room.webp",
        "WEBP",
        quality=88,
        method=6,
    )


def main() -> None:
    for tier in ("wood", "gold", "cosmetic"):
        build_components(tier)
    build_room()
    for asset in sorted(OUTPUT_DIR.glob("*.webp")):
        with Image.open(asset) as image:
            print(f"{asset.name}: {image.width}x{image.height} ({asset.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
