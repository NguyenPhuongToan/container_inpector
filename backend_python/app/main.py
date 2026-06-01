from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.routes.auth_routes import router as auth_router
from app.api.routes.inspection_routes import PHOTO_LABELS, router as inspection_router
from app.api.routes.upload_routes import router as upload_router
from app.core.config import settings
from app.core.rate_limit import limiter
from app.database.db import SessionLocal, init_db
from app.services.auth.bootstrap import seed_default_users


@asynccontextmanager
async def lifespan(app: FastAPI):
    if (
        settings.env == "production"
        and settings.jwt_secret == "change-this-development-secret"
    ):
        raise RuntimeError("JWT_SECRET must be changed in production")

    init_db()
    with SessionLocal() as db:
        seed_default_users(db)
    yield


app = FastAPI(
    title="Container Inspection Backend",
    version="1.0.0",
    lifespan=lifespan,
)

UPLOAD_DIR = Path("uploads")
REPORT_DIR = Path("reports")

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
app.mount("/reports", StaticFiles(directory=REPORT_DIR), name="reports")

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

app.include_router(inspection_router, prefix="/api")
app.include_router(auth_router, prefix="/api")
app.include_router(upload_router, prefix="/api")
app.include_router(upload_router)


@app.get("/")
def root():
    return {"message": "Container Inspection Backend Running"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/api/config")
def config():
    return {"photo_labels": PHOTO_LABELS}
