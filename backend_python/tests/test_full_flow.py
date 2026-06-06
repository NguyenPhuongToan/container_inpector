import importlib
import os
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image


def _configure_environment(tmp_path):
    os.environ["DATABASE_URL"] = f"sqlite:///{tmp_path / 'test.db'}"
    os.environ["JWT_SECRET"] = "test-secret"
    os.environ["SEED_DEMO_USERS"] = "true"
    os.environ["DEMO_WORKER_PASSWORD"] = "worker12345"
    os.environ["DEMO_MANAGER_PASSWORD"] = "manager12345"
    os.environ["DEMO_ADMIN_PASSWORD"] = "admin12345"
    os.environ["MANAGER_EMAIL"] = "manager@example.com"
    os.environ["EMAIL_DELIVERY_MODE"] = "outbox"
    os.environ["EMAIL_OUTBOX_DIR"] = str(tmp_path / "email_outbox")


def _fresh_app(tmp_path, monkeypatch):
    _configure_environment(tmp_path)

    for module_name in list(sys.modules):
        if module_name == "app" or module_name.startswith("app."):
            del sys.modules[module_name]

    main = importlib.import_module("app.main")
    inspection_routes = importlib.import_module("app.api.routes.inspection_routes")
    constants = importlib.import_module("app.core.constants")
    excel_exporter = importlib.import_module("app.services.excel.excel_exporter")
    template_manager = importlib.import_module("app.services.excel.template_manager")

    for module in [constants, inspection_routes]:
        monkeypatch.setattr(module, "UPLOAD_ROOT", tmp_path / "uploads")
        monkeypatch.setattr(module, "REPORT_ROOT", tmp_path / "reports")
        monkeypatch.setattr(module, "OCR_TEMP_ROOT", tmp_path / "ocr")
    monkeypatch.setattr(excel_exporter, "REPORT_ROOT", tmp_path / "reports")
    monkeypatch.setattr(template_manager, "REPORT_ROOT", tmp_path / "reports")
    monkeypatch.setattr(
        inspection_routes,
        "detect_container_number",
        lambda image_path: "TCLU1234565",
    )
    monkeypatch.setattr(
        inspection_routes,
        "detect_flexitank_number",
        lambda image_path: "23TT3-2601-005",
    )

    return main.app


def _image_bytes(label):
    image = Image.new("RGB", (640, 420), color=(184, 78, 46))
    buffer = BytesIO()
    image.save(buffer, format="JPEG", quality=85)
    buffer.seek(0)
    return buffer.getvalue()


def _headers(token):
    return {"Authorization": f"Bearer {token}"}


def _login(client, email, password):
    response = client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def test_worker_manager_admin_flow(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient

    app = _fresh_app(tmp_path, monkeypatch)

    with TestClient(app) as client:
        worker_response = client.post(
            "/api/auth/register-worker",
            json={
                "full_name": "Flow Worker",
                "email": "flow.worker@example.com",
                "password": "workerpass123",
            },
        )
        assert worker_response.status_code == 201, worker_response.text
        worker_token = worker_response.json()["access_token"]

        scan_response = client.post(
            "/api/ai/scan-container-id",
            headers=_headers(worker_token),
            files={"image": ("container.jpg", _image_bytes("container"), "image/jpeg")},
        )
        assert scan_response.status_code == 200, scan_response.text
        assert scan_response.json()["container_number"] == "TCLU1234565"

        flexitank_scan_response = client.post(
            "/api/ai/scan-flexitank-id",
            headers=_headers(worker_token),
            files={"image": ("flexitank.jpg", _image_bytes("flexitank"), "image/jpeg")},
        )
        assert flexitank_scan_response.status_code == 200, flexitank_scan_response.text
        assert flexitank_scan_response.json()["flexitank_number"] == "23TT3-2601-005"

        files = [
            (
                f"image_{index}",
                (f"{index + 1:02d}.jpg", _image_bytes(str(index)), "image/jpeg"),
            )
            for index in range(12)
        ]
        create_response = client.post(
            "/api/inspections",
            headers=_headers(worker_token),
            data={
                "container_number": "TCLU1234565",
                "flexitank_number": "23TT3-2601-005",
                "booking_number": "BOOK-001",
                "truck_number": "TRUCK-001",
                "worker_name": "Flow Worker",
                "port_name": "Test Port",
                "notes": "End-to-end flow test",
            },
            files=files,
        )
        assert create_response.status_code == 201, create_response.text
        inspection = create_response.json()
        assert inspection["status"] == "submitted"
        assert inspection["flexitank_number"] == "23TT3-2601-005"
        assert len(inspection["image_urls"]) == 12
        inspection_id = inspection["id"]

        manager_token = _login(client, "manager@example.com", "manager12345")
        list_response = client.get(
            "/api/inspections",
            headers=_headers(manager_token),
            params={"status": "submitted"},
        )
        assert list_response.status_code == 200, list_response.text
        assert any(item["id"] == inspection_id for item in list_response.json())

        accept_response = client.post(
            f"/api/inspections/{inspection_id}/accept",
            headers=_headers(manager_token),
        )
        assert accept_response.status_code == 200, accept_response.text
        assert accept_response.json()["status"] == "accepted"

        excel_response = client.post(
            f"/api/inspections/{inspection_id}/export-excel-email",
            headers=_headers(manager_token),
        )
        assert excel_response.status_code == 200, excel_response.text
        assert excel_response.json()["email_sent"] is True
        assert Path(tmp_path / "reports" / inspection_id / excel_response.json()["filename"]).exists()

        report_response = client.post(
            f"/api/inspections/{inspection_id}/generate-report-email",
            headers=_headers(manager_token),
        )
        assert report_response.status_code == 200, report_response.text
        assert report_response.json()["email_sent"] is True
        assert Path(tmp_path / "reports" / inspection_id / report_response.json()["filename"]).exists()
        assert len(list((tmp_path / "email_outbox").glob("*.eml"))) >= 2

        admin_token = _login(client, "admin@example.com", "admin12345")
        admin_list = client.get("/api/inspections", headers=_headers(admin_token))
        assert admin_list.status_code == 200, admin_list.text
        assert any(item["id"] == inspection_id for item in admin_list.json())

        admin_files = [
            (
                f"image_{index}",
                (f"admin_{index + 1:02d}.jpg", _image_bytes(str(index)), "image/jpeg"),
            )
            for index in range(12)
        ]
        admin_create = client.post(
            "/api/inspections",
            headers=_headers(admin_token),
            data={
                "container_number": "MSCU6639871",
                "flexitank_number": "23TT3-2601-009",
                "booking_number": "BOOK-ADMIN",
                "truck_number": "TRUCK-ADMIN",
                "worker_name": "Admin User",
                "port_name": "Admin Port",
                "notes": "Admin submit capability",
            },
            files=admin_files,
        )
        assert admin_create.status_code == 201, admin_create.text
