import re
from functools import lru_cache
from pathlib import Path
from threading import Lock
from typing import Any

from paddleocr import PaddleOCR

from app.core.config import settings
from app.services.ai.gemini_service import (
    GeminiServiceError,
    extract_container_number_with_gemini,
)

CONTAINER_NUMBER_PATTERN = re.compile(r"[A-Z]{4}\d{7}")
OCR_CANDIDATE_PATTERN = re.compile(r"[A-Z0-9]{4}\d{7}")

OWNER_CODE_VALUES = {
    "A": 10,
    "B": 12,
    "C": 13,
    "D": 14,
    "E": 15,
    "F": 16,
    "G": 17,
    "H": 18,
    "I": 19,
    "J": 20,
    "K": 21,
    "L": 23,
    "M": 24,
    "N": 25,
    "O": 26,
    "P": 27,
    "Q": 28,
    "R": 29,
    "S": 30,
    "T": 31,
    "U": 32,
    "V": 34,
    "W": 35,
    "X": 36,
    "Y": 37,
    "Z": 38,
}

OCR_LETTER_FIXES = str.maketrans(
    {
        "0": "O",
        "1": "I",
        "5": "S",
        "6": "G",
        "8": "B",
    }
)
OCR_DIGIT_FIXES = str.maketrans(
    {
        "O": "0",
        "Q": "0",
        "D": "0",
        "I": "1",
        "L": "1",
        "Z": "2",
        "S": "5",
        "B": "8",
        "G": "6",
    }
)

_OCR_LOCK = Lock()


class ContainerOcrError(RuntimeError):
    """Raised when all OCR providers fail to return a container number."""


@lru_cache(maxsize=1)
def _get_ocr() -> PaddleOCR:
    return PaddleOCR(lang="en")


def _normalize_text(text: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "", text.upper())


def _shape_container_candidate(raw_candidate: str) -> str | None:
    value = _normalize_text(raw_candidate)
    if len(value) != 11:
        return None

    owner = value[:4].translate(OCR_LETTER_FIXES)
    serial = value[4:].translate(OCR_DIGIT_FIXES)
    candidate = f"{owner}{serial}"

    if CONTAINER_NUMBER_PATTERN.fullmatch(candidate):
        return candidate

    return None


def is_valid_iso_6346(container_number: str) -> bool:
    value = _shape_container_candidate(container_number)
    if value is None:
        return False

    total = 0
    for index, character in enumerate(value[:10]):
        if character.isalpha():
            number = OWNER_CODE_VALUES.get(character)
            if number is None:
                return False
        else:
            number = int(character)

        total += number * (2 ** index)

    check_digit = total % 11
    if check_digit == 10:
        check_digit = 0

    return check_digit == int(value[-1])


def _extract_recognized_texts(ocr_result: Any) -> list[tuple[str, float]]:
    texts: list[tuple[str, float]] = []

    if isinstance(ocr_result, list):
        for item in ocr_result:
            texts.extend(_extract_recognized_texts(item))
        return texts

    if isinstance(ocr_result, dict):
        rec_texts = ocr_result.get("rec_texts") or []
        rec_scores = ocr_result.get("rec_scores") or []
        for index, text in enumerate(rec_texts):
            score = rec_scores[index] if index < len(rec_scores) else 0.0
            texts.append((str(text), float(score)))
        return texts

    return texts


def _candidate_sources(texts: list[tuple[str, float]]) -> list[tuple[str, float]]:
    sources: list[tuple[str, float]] = []
    normalized_texts = [(_normalize_text(text), score) for text, score in texts]
    normalized_texts = [(text, score) for text, score in normalized_texts if text]

    sources.extend(normalized_texts)

    for index in range(len(normalized_texts)):
        combined = ""
        scores: list[float] = []
        for text, score in normalized_texts[index:index + 4]:
            combined += text
            scores.append(score)
            sources.append((combined, min(scores)))

    all_text = "".join(text for text, _ in normalized_texts)
    if all_text:
        average_score = sum(score for _, score in normalized_texts) / len(normalized_texts)
        sources.append((all_text, average_score))

    return sources


def _find_best_container_number(texts: list[tuple[str, float]]) -> str | None:
    candidates: list[tuple[str, float, bool]] = []

    for source, score in _candidate_sources(texts):
        for match in OCR_CANDIDATE_PATTERN.finditer(source):
            candidate = _shape_container_candidate(match.group(0))
            if candidate is None:
                continue
            candidates.append((candidate, score, is_valid_iso_6346(candidate)))

    if not candidates:
        return None

    candidates.sort(key=lambda item: (item[2], item[1]), reverse=True)
    best_candidate, _, is_valid = candidates[0]

    if is_valid:
        return best_candidate

    return best_candidate


def detect_container_number(image_path: Path) -> str:
    container_number: str | None = None

    try:
        with _OCR_LOCK:
            result = _get_ocr().predict(str(image_path))
        recognized_texts = _extract_recognized_texts(result)
        container_number = _find_best_container_number(recognized_texts)
    except Exception:
        container_number = None

    if container_number is not None:
        return container_number

    gemini_error: GeminiServiceError | None = None
    if settings.gemini_configured:
        try:
            return extract_container_number_with_gemini(image_path)
        except GeminiServiceError as exc:
            gemini_error = exc

    raise ContainerOcrError("Container number could not be detected") from gemini_error
