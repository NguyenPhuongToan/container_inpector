from collections.abc import Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database.db import get_db
from app.database.models import User

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    payload = decode_access_token(credentials.credentials)
    user = db.get(User, payload.get("sub"))

    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    return user


def require_roles(*roles: str) -> Callable:
    allowed_roles = set(roles)

    def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in allowed_roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        return user

    return dependency


WorkerUser = Depends(require_roles("worker", "admin"))
ManagerUser = Depends(require_roles("manager", "admin"))
AnyUser = Depends(get_current_user)
