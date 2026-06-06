from __future__ import annotations

import argparse
import json
import mimetypes
from pathlib import Path
from urllib import error, request


PHOTO_LABELS = [
    "Container Door Number",
    "Flexitank Serial Number",
    "Front",
    "Rear",
    "Left Side",
    "Right Side",
    "Front Left",
    "Front Right",
    "Rear Left",
    "Rear Right",
    "Ceiling",
    "Floor",
]


def build_multipart(
    fields: dict[str, str],
    image_paths: list[Path],
    boundary: str,
) -> bytes:
    body = bytearray()

    for name, value in fields.items():
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        )
        body.extend(value.encode())
        body.extend(b"\r\n")

    for index, image_path in enumerate(image_paths):
        content_type = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(
            (
                f'Content-Disposition: form-data; name="image_{index}"; '
                f'filename="{image_path.name}"\r\n'
            ).encode()
        )
        body.extend(f"Content-Type: {content_type}\r\n\r\n".encode())
        body.extend(image_path.read_bytes())
        body.extend(b"\r\n")

    body.extend(f"--{boundary}--\r\n".encode())
    return bytes(body)


def find_images(image_dir: Path) -> list[Path]:
    image_paths = sorted(
        [
            path
            for path in image_dir.iterdir()
            if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        ]
    )

    if len(image_paths) != len(PHOTO_LABELS):
        raise SystemExit(
            f"Expected {len(PHOTO_LABELS)} images in {image_dir}, "
            f"found {len(image_paths)}."
        )

    return image_paths


def login(base_url: str, email: str, password: str) -> str:
    body = json.dumps({"email": email, "password": password}).encode("utf-8")
    req = request.Request(
        f"{base_url.rstrip('/')}/api/auth/login",
        data=body,
        method="POST",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )

    with request.urlopen(req, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))

    return payload["access_token"]


def submit_inspection(base_url: str, image_dir: Path, token: str) -> None:
    image_paths = find_images(image_dir)
    boundary = "----container-inspection-test-boundary"
    fields = {
        "container_number": "TCLU1234565",
        "flexitank_number": "23TT3-2601-005",
        "booking_number": "BOOKING-TEST-001",
        "truck_number": "TRUCK-TEST-001",
        "worker_name": "Test Worker",
        "port_name": "Test Port",
        "notes": "Submitted by backend test script.",
    }
    body = build_multipart(fields, image_paths, boundary)
    url = f"{base_url.rstrip('/')}/api/inspections"

    req = request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
    )

    try:
        with request.urlopen(req, timeout=90) as response:
            payload = response.read().decode("utf-8")
            print(f"Status: {response.status}")
            print(json.dumps(json.loads(payload), indent=2))
    except error.HTTPError as exc:
        print(f"Status: {exc.code}")
        print(exc.read().decode("utf-8"))
        raise SystemExit(1) from exc


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Submit a test inspection with 12 indexed image files."
    )
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8000",
        help="Backend base URL. Default: http://127.0.0.1:8000",
    )
    parser.add_argument(
        "--image-dir",
        required=True,
        type=Path,
        help="Folder containing exactly 12 jpg/png/webp images.",
    )
    parser.add_argument(
        "--email",
        default="worker@example.com",
        help="Worker login email. Default: worker@example.com",
    )
    parser.add_argument(
        "--password",
        default="worker12345",
        help="Worker login password. Default: worker12345",
    )
    args = parser.parse_args()

    token = login(args.base_url, args.email, args.password)
    submit_inspection(args.base_url, args.image_dir, token)


if __name__ == "__main__":
    main()
