from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.core.constants import OCR_TEMP_ROOT, REPORT_ROOT


def _remove_empty_parents(path: Path, stop_at: Path) -> None:
    current = path.parent
    stop_at = stop_at.resolve()

    while current.exists() and current.resolve() != stop_at:
        try:
            current.rmdir()
        except OSError:
            return
        current = current.parent


def _delete_old_files(root: Path, cutoff: datetime) -> int:
    deleted = 0
    if not root.exists():
        return deleted

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        modified_at = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
        if modified_at >= cutoff:
            continue

        path.unlink(missing_ok=True)
        deleted += 1
        _remove_empty_parents(path, root)

    return deleted


def cleanup_old_files(max_age_hours: int = 24) -> int:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
    deleted = 0
    deleted += _delete_old_files(OCR_TEMP_ROOT, cutoff)
    deleted += _delete_old_files(REPORT_ROOT, cutoff)
    return deleted
