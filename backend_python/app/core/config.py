import os
from dataclasses import dataclass, field
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


def _get_bool(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


def _get_csv(name: str, default: str = "") -> list[str]:
    return [
        item.strip()
        for item in os.getenv(name, default).split(",")
        if item.strip()
    ]


@dataclass(frozen=True)
class Settings:
    env: str = os.getenv("ENV", "development")
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://postgres:postgres@localhost:5432/container_inspection",
    )
    jwt_secret: str = os.getenv("JWT_SECRET", "change-this-development-secret")
    jwt_expires_minutes: int = int(os.getenv("JWT_EXPIRES_MINUTES", "1440"))
    allowed_origins: str = os.getenv(
        "ALLOWED_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000",
    )
    seed_demo_users: bool = _get_bool("SEED_DEMO_USERS", "true")
    demo_worker_email: str = os.getenv("DEMO_WORKER_EMAIL", "worker@example.com")
    demo_worker_password: str = os.getenv("DEMO_WORKER_PASSWORD", "worker12345")
    demo_manager_email: str = os.getenv("DEMO_MANAGER_EMAIL", "manager@example.com")
    demo_manager_password: str = os.getenv("DEMO_MANAGER_PASSWORD", "manager12345")
    demo_admin_email: str = os.getenv("DEMO_ADMIN_EMAIL", "admin@example.com")
    demo_admin_password: str = os.getenv("DEMO_ADMIN_PASSWORD", "admin12345")
    manager_email: str = os.getenv("MANAGER_EMAIL", "")
    smtp_host: str = os.getenv("SMTP_HOST", "")
    smtp_port: int = int(os.getenv("SMTP_PORT", "587"))
    smtp_username: str = os.getenv("SMTP_USERNAME", "")
    smtp_password: str = os.getenv("SMTP_PASSWORD", "")
    smtp_from: str = os.getenv("SMTP_FROM", os.getenv("SMTP_USERNAME", ""))
    smtp_use_tls: bool = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    email_delivery_mode: str = os.getenv("EMAIL_DELIVERY_MODE", "outbox").lower()
    email_outbox_dir: str = os.getenv("EMAIL_OUTBOX_DIR", "reports/email_outbox")
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    fitting_photo_template_path: str = os.getenv(
        "FITTING_PHOTO_TEMPLATE_PATH",
        "templates/fitting_photo_template.pptx",
    )
    cors_origins: list[str] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not self.cors_origins:
            object.__setattr__(
                self,
                "cors_origins",
                [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()],
            )

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

    @property
    def gemini_configured(self) -> bool:
        return bool(self.gemini_api_key)


settings = Settings()
