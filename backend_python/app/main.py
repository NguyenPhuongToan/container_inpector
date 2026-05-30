from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes.auth_routes import router as auth_router
from app.api.routes.inspection_routes import router as inspection_router
from app.api.routes.upload_routes import router as upload_router
from app.database.db import SessionLocal, init_db
from app.services.auth.bootstrap import seed_default_users

app = FastAPI(
    title="Container Inspection Backend",
    version="1.0.0",
)

UPLOAD_DIR = Path("uploads")
REPORT_DIR = Path("reports")

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
app.mount("/reports", StaticFiles(directory=REPORT_DIR), name="reports")

app.include_router(inspection_router, prefix="/api")
app.include_router(auth_router, prefix="/api")
app.include_router(upload_router)


@app.on_event("startup")
def startup() -> None:
    init_db()
    with SessionLocal() as db:
        seed_default_users(db)


@app.get("/")
def root():
    return {"message": "Container Inspection Backend Running"}


@app.get("/health")
def health():
    return {"status": "healthy"}
