import smtplib
from email.message import EmailMessage
from pathlib import Path
from uuid import uuid4

from app.core.config import settings


class EmailConfigurationError(RuntimeError):
    """Raised when no email recipient or delivery settings are available."""


def send_email_with_attachment(
    *,
    subject: str,
    body: str,
    attachment_path: Path,
    to_email: str | None = None,
) -> dict[str, str | bool]:
    recipient = to_email or settings.manager_email

    if not recipient:
        raise EmailConfigurationError("SMTP email settings are not configured")

    if not attachment_path.exists():
        raise FileNotFoundError(f"Attachment not found: {attachment_path}")

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.smtp_from
    message["To"] = recipient
    message.set_content(body)

    message.add_attachment(
        attachment_path.read_bytes(),
        maintype="application",
        subtype="octet-stream",
        filename=attachment_path.name,
    )

    if settings.email_delivery_mode == "outbox" or not settings.email_configured:
        outbox_dir = Path(settings.email_outbox_dir)
        outbox_dir.mkdir(parents=True, exist_ok=True)
        outbox_path = outbox_dir / f"{uuid4()}.eml"
        outbox_path.write_bytes(bytes(message))
        return {
            "sent": True,
            "to": recipient,
            "delivery": "outbox",
            "path": str(outbox_path),
        }

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=30) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        smtp.login(settings.smtp_username, settings.smtp_password)
        smtp.send_message(message)

    return {
        "sent": True,
        "to": recipient,
        "delivery": "smtp",
    }
