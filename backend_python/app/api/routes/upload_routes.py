from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, UploadFile
from starlette.concurrency import run_in_threadpool

from app.api.dependencies import require_roles
from app.database.models import User
from app.services.storage.image_storage import save_upload, validate_image

router = APIRouter(tags=["uploads"])

UPLOAD_DIR = Path("uploads/original")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/upload")
@router.post("/uploads/upload")
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(require_roles("worker", "admin")),
):
    suffix = validate_image(file)
    file_path = UPLOAD_DIR / f"{uuid4()}{suffix}"
    await run_in_threadpool(save_upload, file, file_path)

    return {
        "filename": file_path.name,
        "status": "uploaded",
    }
