from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password
from app.database.models import User


def _seed_users() -> list[dict[str, str]]:
    if not settings.seed_demo_users:
        return []

    return [
        {
            "email": settings.demo_worker_email,
            "full_name": "Default Worker",
            "role": "worker",
            "password": settings.demo_worker_password,
        },
        {
            "email": settings.demo_manager_email,
            "full_name": "Default Manager",
            "role": "manager",
            "password": settings.demo_manager_password,
        },
        {
            "email": settings.demo_admin_email,
            "full_name": "Default Admin",
            "role": "admin",
            "password": settings.demo_admin_password,
        },
    ]


def seed_default_users(db: Session) -> None:
    for user_data in _seed_users():
        existing = db.scalar(
            select(User).where(User.email == user_data["email"].lower())
        )
        if existing is not None:
            continue

        db.add(
            User(
                email=user_data["email"].lower(),
                full_name=user_data["full_name"],
                role=user_data["role"],
                password_hash=hash_password(user_data["password"]),
            )
        )

    db.commit()
