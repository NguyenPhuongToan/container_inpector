import base64
import json
from types import SimpleNamespace


def _decode_payload(token: str) -> dict:
    encoded_payload = token.split(".")[1]
    padding = "=" * (-len(encoded_payload) % 4)
    return json.loads(base64.urlsafe_b64decode(encoded_payload + padding))


def test_worker_tokens_use_worker_expiry(monkeypatch):
    from app.core import security

    monkeypatch.setattr(
        security,
        "settings",
        SimpleNamespace(
            jwt_secret="test-secret",
            jwt_expires_minutes=1440,
            worker_jwt_expires_minutes=10080,
        ),
    )

    worker_token = security.create_access_token(
        user_id="worker-id",
        role="worker",
        email="worker@example.com",
    )
    manager_token = security.create_access_token(
        user_id="manager-id",
        role="manager",
        email="manager@example.com",
    )

    worker_payload = _decode_payload(worker_token)
    manager_payload = _decode_payload(manager_token)

    assert worker_payload["exp"] - manager_payload["exp"] >= 6 * 24 * 60 * 60
