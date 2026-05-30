from fastapi import APIRouter, UploadFile, File
import shutil
from pathlib import Path

router = APIRouter()

UPLOAD_DIR = Path("uploads/original")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    file_path = UPLOAD_DIR / file.filename

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return {
        "filename": file.filename,
        "status": "uploaded"
    }