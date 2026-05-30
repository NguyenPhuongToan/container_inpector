import os
from dataclasses import dataclass
from pathlib import Path


def _load_dotenv(path: Path = Path(".env")) -> None:
    if not path.exists():
        return

    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_dotenv()


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://postgres:postgres@localhost:5432/container_inspection",
    )
    jwt_secret: str = os.getenv("JWT_SECRET", "change-this-development-secret")
    jwt_expires_minutes: int = int(os.getenv("JWT_EXPIRES_MINUTES", "1440"))
    manager_email: str = os.getenv("MANAGER_EMAIL", "")
    smtp_host: str = os.getenv("SMTP_HOST", "")
    smtp_port: int = int(os.getenv("SMTP_PORT", "587"))
    smtp_username: str = os.getenv("SMTP_USERNAME", "")
    smtp_password: str = os.getenv("SMTP_PASSWORD", "")
    smtp_from: str = os.getenv("SMTP_FROM", os.getenv("SMTP_USERNAME", ""))
    smtp_use_tls: bool = os.getenv("SMTP_USE_TLS", "true").lower() == "true"

    @property
    def email_configured(self) -> bool:
        return all(
            [
                self.manager_email,
                self.smtp_host,
                self.smtp_username,
                self.smtp_password,
                self.smtp_from,
            ]
        )


settings = Settings()
