from pathlib import Path


def image_suffix(path: str | Path) -> str:
    return Path(path).suffix.lower()
