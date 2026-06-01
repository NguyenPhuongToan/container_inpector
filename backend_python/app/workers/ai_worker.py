from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.database.models import Inspection
from app.services.ai.container_ocr import ContainerOcrError, detect_container_number


def retry_ocr_scan(inspection_id: str, db: Session) -> None:
    inspection = db.scalar(
        select(Inspection)
        .options(selectinload(Inspection.images))
        .where(Inspection.id == inspection_id)
    )
    if inspection is None or inspection.container_number.strip():
        return

    first_image = next(
        (image for image in sorted(inspection.images, key=lambda item: item.angle)),
        None,
    )
    if first_image is None:
        return

    try:
        inspection.container_number = detect_container_number(Path(first_image.path))
    except (ContainerOcrError, OSError):
        return

    inspection.updated_at = datetime.now(timezone.utc)
    db.commit()
