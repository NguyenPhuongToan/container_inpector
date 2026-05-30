import smtplib
from email.message import EmailMessage
from pathlib import Path

from app.core.config import settings


class EmailConfigurationError(RuntimeError):
    pass


def send_email_with_attachment(
    *,
    subject: str,
    body: str,
    attachment_path: Path,
    to_email: str | None = None,
) -> dict[str, str | bool]:
    recipient = to_email or settings.manager_email

    if not settings.email_configured:
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

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=30) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        smtp.login(settings.smtp_username, settings.smtp_password)
        smtp.send_message(message)

    return {
        "sent": True,
        "to": recipient,
    }
