from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.db import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def uuid_str() -> str:
    return str(uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(32), index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    inspections: Mapped[list["Inspection"]] = relationship(
        foreign_keys="Inspection.worker_id",
        back_populates="worker",
    )


class Inspection(Base):
    __tablename__ = "inspections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    container_number: Mapped[str] = mapped_column(String(32), index=True)
    booking_number: Mapped[str] = mapped_column(String(128))
    truck_number: Mapped[str] = mapped_column(String(128))
    worker_name: Mapped[str] = mapped_column(String(255))
    port_name: Mapped[str] = mapped_column(String(255), index=True)
    notes: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(32), index=True, default="submitted")
    worker_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    accepted_by_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    rejected_by_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
    )

    worker: Mapped[User | None] = relationship(
        foreign_keys=[worker_id],
        back_populates="inspections",
    )
    images: Mapped[list["InspectionImage"]] = relationship(
        back_populates="inspection",
        cascade="all, delete-orphan",
        order_by="InspectionImage.angle",
    )
    exports: Mapped[list["ExportRecord"]] = relationship(
        back_populates="inspection",
        cascade="all, delete-orphan",
    )


class InspectionImage(Base):
    __tablename__ = "inspection_images"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    inspection_id: Mapped[str] = mapped_column(ForeignKey("inspections.id"), index=True)
    angle: Mapped[int] = mapped_column(Integer)
    label: Mapped[str] = mapped_column(String(128))
    url: Mapped[str] = mapped_column(Text)
    path: Mapped[str] = mapped_column(Text)

    inspection: Mapped[Inspection] = relationship(back_populates="images")


class ExportRecord(Base):
    __tablename__ = "export_records"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    inspection_id: Mapped[str] = mapped_column(ForeignKey("inspections.id"), index=True)
    export_type: Mapped[str] = mapped_column(String(32))
    filename: Mapped[str] = mapped_column(String(255))
    report_url: Mapped[str] = mapped_column(Text)
    email_sent: Mapped[bool] = mapped_column(default=False)
    email_to: Mapped[str | None] = mapped_column(String(255), nullable=True)
    message: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    inspection: Mapped[Inspection] = relationship(back_populates="exports")
