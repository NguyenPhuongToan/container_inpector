import mimetypes
import re
from pathlib import Path

import google.generativeai as genai

from app.core.config import settings


CONTAINER_NUMBER_PATTERN = re.compile(r"[A-Z]{4}\d{7}")


class GeminiServiceError(RuntimeError):
    """Raised when Gemini OCR fallback cannot return a container number."""


def extract_container_number_with_gemini(image_path: Path) -> str:
    if not settings.gemini_configured:
        raise GeminiServiceError("GEMINI_API_KEY is not configured")

    if not image_path.exists():
        raise GeminiServiceError(f"Image not found: {image_path}")

    genai.configure(api_key=settings.gemini_api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")
    mime_type = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
    prompt = (
        "Read the ISO 6346 shipping container number from this image. "
        "Return only the 11-character container number, or NOT_FOUND."
    )

    try:
        response = model.generate_content(
            [
                prompt,
                {
                    "mime_type": mime_type,
                    "data": image_path.read_bytes(),
                },
            ]
        )
    except Exception as exc:
        raise GeminiServiceError("Gemini OCR request failed") from exc

    text = (getattr(response, "text", "") or "").upper()
    match = CONTAINER_NUMBER_PATTERN.search(text)
    if not match:
        raise GeminiServiceError("NOT_FOUND")

    return match.group(0)
