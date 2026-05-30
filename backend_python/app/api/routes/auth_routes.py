from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password, verify_password
from app.database.db import get_db
from app.database.models import User
from app.schemas.auth_schema import (
    LoginRequest,
    LoginResponse,
    RegisterWorkerRequest,
    UserResponse,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _login_response(user: User) -> LoginResponse:
    token = create_access_token(user_id=user.id, role=user.role, email=user.email)
    return LoginResponse(
        access_token=token,
        user=UserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
        ),
    )


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))

    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled",
        )

    return _login_response(user)


@router.post(
    "/register-worker",
    response_model=LoginResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_worker(payload: RegisterWorkerRequest, db: Session = Depends(get_db)):
    email = payload.email.lower()
    full_name = payload.full_name.strip()

    if len(full_name) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Full name is required",
        )

    existing = db.scalar(select(User).where(User.email == email))

    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    user = User(
        email=email,
        full_name=full_name,
        role="worker",
        password_hash=hash_password(payload.password),
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return _login_response(user)
