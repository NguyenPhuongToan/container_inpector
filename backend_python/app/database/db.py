from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy import inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings


class Base(DeclarativeBase):
    __abstract__ = True


engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    from app.database import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    _ensure_lightweight_migrations()


def _ensure_lightweight_migrations() -> None:
    inspector = inspect(engine)
    if "inspections" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("inspections")}
    if "flexitank_number" in columns:
        return

    with engine.begin() as connection:
        connection.execute(
            text("ALTER TABLE inspections ADD COLUMN flexitank_number VARCHAR(128) DEFAULT ''")
        )
