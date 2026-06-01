from pathlib import Path

from fastapi import HTTPException, UploadFile


MAX_IMAGE_SIZE = 10 * 1024 * 1024
CHUNK_SIZE = 1024 * 1024
ALLOWED_IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/octet-stream",
}


def validate_image(image: UploadFile) -> str:
    suffix = Path(image.filename or "").suffix.lower()
    if suffix not in ALLOWED_IMAGE_SUFFIXES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image file type: {suffix or 'unknown'}",
        )

    content_type = (image.content_type or "").lower()
    if content_type and content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image content type: {content_type}",
        )

    return suffix


def save_upload(image: UploadFile, dest: Path) -> Path:
    validate_image(image)
    dest.parent.mkdir(parents=True, exist_ok=True)
    total_size = 0

    try:
        image.file.seek(0)
        with dest.open("wb") as buffer:
            while chunk := image.file.read(CHUNK_SIZE):
                total_size += len(chunk)
                if total_size > MAX_IMAGE_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail="Image is too large. Maximum size is 10MB.",
                    )
                buffer.write(chunk)
    except HTTPException:
        dest.unlink(missing_ok=True)
        raise
    except OSError as exc:
        dest.unlink(missing_ok=True)
        raise HTTPException(status_code=500, detail="Could not save uploaded image") from exc

    if total_size == 0:
        dest.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="Uploaded image is empty")

    return dest
