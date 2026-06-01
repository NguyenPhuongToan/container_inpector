import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import select

from app.core.constants import OCR_TEMP_ROOT
from app.database.db import SessionLocal
from app.database.models import Inspection
from app.services.storage.cleanup_service import cleanup_old_files


def _delete_path(path: Path) -> int:
    if not path.exists():
        return 0

    if path.is_dir():
        shutil.rmtree(path)
        return 1

    path.unlink(missing_ok=True)
    return 1


def run_cleanup() -> None:
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)

    with SessionLocal() as db:
        rejected_inspections = db.scalars(
            select(Inspection).where(
                Inspection.status == "rejected",
                Inspection.updated_at < seven_days_ago,
            )
        ).all()

        for inspection in rejected_inspections:
            _delete_path(Path("uploads/inspections") / inspection.id)

    one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    if OCR_TEMP_ROOT.exists():
        for path in OCR_TEMP_ROOT.glob("*"):
            if not path.is_file():
                continue
            modified_at = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
            if modified_at < one_hour_ago:
                path.unlink(missing_ok=True)

    cleanup_old_files()
