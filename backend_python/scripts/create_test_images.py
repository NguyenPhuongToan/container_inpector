from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PHOTO_LABELS = [
    "Container Door Number",
    "Flexitank Serial Number",
    "Front",
    "Rear",
    "Left Side",
    "Right Side",
    "Front Left",
    "Front Right",
    "Rear Left",
    "Rear Right",
    "Ceiling",
    "Floor",
]


def create_images(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        font = ImageFont.truetype("arial.ttf", 34)
        small_font = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    for index, label in enumerate(PHOTO_LABELS):
        image = Image.new("RGB", (900, 650), color=(184, 78, 46))
        draw = ImageDraw.Draw(image)

        draw.rectangle((0, 0, 900, 90), fill=(7, 93, 204))
        draw.text((32, 26), f"{index + 1:02d} - {label}", fill="white", font=font)

        draw.rectangle((90, 150, 810, 560), outline=(58, 35, 25), width=8)
        draw.line((450, 150, 450, 560), fill=(58, 35, 25), width=5)
        draw.text((210, 270), "TCLU", fill="white", font=font)
        draw.text((210, 325), "123456 5", fill="white", font=font)
        draw.text((210, 380), "23TT3-2601-005", fill="white", font=small_font)
        draw.text((210, 405), "TEST IMAGE", fill=(245, 245, 245), font=small_font)

        filename = f"{index + 1:02d}_{label.lower().replace(' ', '_')}.jpg"
        image.save(output_dir / filename, quality=85)


def main() -> None:
    parser = argparse.ArgumentParser(description="Create 12 test inspection images.")
    parser.add_argument(
        "--output-dir",
        default=Path("tmp/test_inspection_images"),
        type=Path,
        help="Output folder. Default: tmp/test_inspection_images",
    )
    args = parser.parse_args()
    create_images(args.output_dir)
    print(f"Created {len(PHOTO_LABELS)} images in {args.output_dir}")


if __name__ == "__main__":
    main()
