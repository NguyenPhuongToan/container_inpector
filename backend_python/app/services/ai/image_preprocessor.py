from pathlib import Path

from PIL import Image


def normalize_for_ocr(image_path: Path) -> Path:
    with Image.open(image_path) as image:
        image.convert("RGB").save(image_path)
    return image_path
