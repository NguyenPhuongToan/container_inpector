from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.database.models import User

DEFAULT_USERS = [
    {
        "email": "worker@example.com",
        "full_name": "Default Worker",
        "role": "worker",
        "password": "worker123",
    },
    {
        "email": "manager@example.com",
        "full_name": "Default Manager",
        "role": "manager",
        "password": "manager123",
    },
    {
        "email": "admin@example.com",
        "full_name": "Default Admin",
        "role": "admin",
        "password": "admin123",
    },
]


def seed_default_users(db: Session) -> None:
    for user_data in DEFAULT_USERS:
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
