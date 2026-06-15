"""
Extended backend test suite for the Container Inspection System.

The suite covers auth, RBAC, inspection lifecycle, exports, OCR endpoints,
ISO 6346 validation, and health/config endpoints.
"""

import base64
import importlib
import json
import os
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image


def _configure_environment(tmp_path):
    os.environ["DATABASE_URL"] = f"sqlite:///{tmp_path / 'test.db'}"
    os.environ["JWT_SECRET"] = "test-secret-suite"
    os.environ["JWT_EXPIRES_MINUTES"] = "1440"
    os.environ["WORKER_JWT_EXPIRES_MINUTES"] = "10080"
    os.environ["SEED_DEMO_USERS"] = "true"
    os.environ["DEMO_WORKER_PASSWORD"] = "worker12345"
    os.environ["DEMO_MANAGER_PASSWORD"] = "manager12345"
    os.environ["DEMO_ADMIN_PASSWORD"] = "admin12345"
    os.environ["MANAGER_EMAIL"] = "manager@example.com"
    os.environ["EMAIL_DELIVERY_MODE"] = "outbox"
    os.environ["EMAIL_OUTBOX_DIR"] = str(tmp_path / "email_outbox")
    os.environ["GEMINI_API_KEY"] = ""


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
    fitting_photo_exporter = importlib.import_module(
        "app.services.presentation.fitting_photo_exporter"
    )

    for module in [constants, inspection_routes]:
        monkeypatch.setattr(module, "UPLOAD_ROOT", tmp_path / "uploads")
        monkeypatch.setattr(module, "REPORT_ROOT", tmp_path / "reports")
        monkeypatch.setattr(module, "OCR_TEMP_ROOT", tmp_path / "ocr")

    monkeypatch.setattr(excel_exporter, "REPORT_ROOT", tmp_path / "reports")
    monkeypatch.setattr(template_manager, "REPORT_ROOT", tmp_path / "reports")
    monkeypatch.setattr(fitting_photo_exporter, "REPORT_ROOT", tmp_path / "reports")
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


def _jpeg_bytes():
    image = Image.new("RGB", (320, 240), color=(100, 150, 200))
    buffer = BytesIO()
    image.save(buffer, format="JPEG", quality=80)
    buffer.seek(0)
    return buffer.getvalue()


def _image_files(count=12):
    return [
        (f"image_{index}", (f"{index + 1:02d}.jpg", _jpeg_bytes(), "image/jpeg"))
        for index in range(count)
    ]


def _headers(token):
    return {"Authorization": f"Bearer {token}"}


def _login(client, email, password):
    response = client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _register_worker(
    client,
    email="worker@test.com",
    password="pass12345",
    name="Test Worker",
):
    response = client.post(
        "/api/auth/register-worker",
        json={"full_name": name, "email": email, "password": password},
    )
    assert response.status_code == 201, response.text
    return response.json()["access_token"]


def _create_inspection(client, token, **overrides):
    data = {
        "container_number": "TCLU1234565",
        "flexitank_number": "23TT3-2601-005",
        "booking_number": "BK-001",
        "truck_number": "TR-001",
        "worker_name": "Test Worker",
        "port_name": "Test Port",
        "notes": "",
        **overrides,
    }
    response = client.post(
        "/api/inspections",
        headers=_headers(token),
        data=data,
        files=_image_files(),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _decode_token_payload(token):
    encoded_payload = token.split(".")[1]
    padding = "=" * (-len(encoded_payload) % 4)
    return json.loads(base64.urlsafe_b64decode(encoded_payload + padding))


class TestAuth:
    def test_register_and_login(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client, "new@test.com", name="New User")
            assert token
            assert _login(client, "new@test.com", "pass12345")

    def test_duplicate_email_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            _register_worker(client, "dup@test.com")
            response = client.post(
                "/api/auth/register-worker",
                json={
                    "full_name": "Dup User",
                    "email": "dup@test.com",
                    "password": "pass12345",
                },
            )
            assert response.status_code == 409

    def test_wrong_password_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            _register_worker(client, "wrong-password@test.com")
            response = client.post(
                "/api/auth/login",
                json={
                    "email": "wrong-password@test.com",
                    "password": "wrongpassword",
                },
            )
            assert response.status_code == 401

    def test_unknown_email_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.post(
                "/api/auth/login",
                json={"email": "nobody@test.com", "password": "pass12345"},
            )
            assert response.status_code == 401

    def test_short_name_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.post(
                "/api/auth/register-worker",
                json={
                    "full_name": "A",
                    "email": "short@test.com",
                    "password": "pass12345",
                },
            )
            assert response.status_code == 422

    def test_invalid_token_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.get(
                "/api/inspections",
                headers={"Authorization": "Bearer notavalidtoken"},
            )
            assert response.status_code == 401

    def test_no_token_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.get("/api/inspections")
            assert response.status_code == 401

    def test_email_case_insensitive(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            _register_worker(client, "Case@Test.com", name="Case User")
            assert _login(client, "CASE@TEST.COM", "pass12345")

    def test_worker_token_uses_seven_day_expiry(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client, "token-worker@test.com")
            manager_token = _login(client, "manager@example.com", "manager12345")

            worker_payload = _decode_token_payload(worker_token)
            manager_payload = _decode_token_payload(manager_token)

            assert worker_payload["role"] == "worker"
            assert manager_payload["role"] == "manager"
            assert worker_payload["exp"] - manager_payload["exp"] >= 6 * 24 * 60 * 60


class TestRBAC:
    def test_worker_cannot_accept_inspection(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            inspection = _create_inspection(client, token)
            response = client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(token),
            )
            assert response.status_code == 403

    def test_worker_cannot_reject_inspection(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            inspection = _create_inspection(client, token)
            response = client.post(
                f"/api/inspections/{inspection['id']}/reject",
                headers=_headers(token),
            )
            assert response.status_code == 403

    def test_worker_cannot_export(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")
            client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )

            response = client.post(
                f"/api/inspections/{inspection['id']}/export-excel-email",
                headers=_headers(worker_token),
            )
            assert response.status_code == 403

    def test_worker_cannot_see_other_workers_inspections(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token_a = _register_worker(client, "worker-a@test.com", name="Worker A")
            token_b = _register_worker(client, "worker-b@test.com", name="Worker B")
            inspection = _create_inspection(client, token_a)

            response = client.get("/api/inspections", headers=_headers(token_b))
            assert response.status_code == 200
            assert inspection["id"] not in [item["id"] for item in response.json()]

    def test_worker_cannot_fetch_other_workers_inspection_by_id(
        self,
        tmp_path,
        monkeypatch,
    ):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token_a = _register_worker(client, "worker-a2@test.com", name="Worker A2")
            token_b = _register_worker(client, "worker-b2@test.com", name="Worker B2")
            inspection = _create_inspection(client, token_a)

            response = client.get(
                f"/api/inspections/{inspection['id']}",
                headers=_headers(token_b),
            )
            assert response.status_code == 403

    def test_manager_can_see_all_inspections(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")

            response = client.get("/api/inspections", headers=_headers(manager_token))
            assert response.status_code == 200
            assert inspection["id"] in [item["id"] for item in response.json()]

    def test_manager_cannot_submit_inspection(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            manager_token = _login(client, "manager@example.com", "manager12345")
            response = client.post(
                "/api/inspections",
                headers=_headers(manager_token),
                data={
                    "container_number": "TCLU1234565",
                    "flexitank_number": "23TT3-2601-005",
                    "booking_number": "BK-001",
                    "truck_number": "TR-001",
                    "worker_name": "Manager",
                    "port_name": "Port",
                    "notes": "",
                },
                files=_image_files(),
            )
            assert response.status_code == 403

    def test_admin_can_submit_and_accept(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            admin_token = _login(client, "admin@example.com", "admin12345")
            inspection = _create_inspection(client, admin_token)
            assert inspection["status"] == "submitted"

            response = client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(admin_token),
            )
            assert response.status_code == 200
            assert response.json()["status"] == "accepted"


class TestInspectionLifecycle:
    def test_submit_inspection_returns_correct_fields(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            inspection = _create_inspection(
                client,
                token,
                container_number="MSCU6639871",
            )

            assert inspection["container_number"] == "MSCU6639871"
            assert inspection["status"] == "submitted"
            assert len(inspection["image_urls"]) == 12
            assert len(inspection["images"]) == 12
            assert all(image["label"] for image in inspection["images"])

    def test_image_labels_in_correct_order(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            inspection = _create_inspection(client, token)
            labels = [image["label"] for image in inspection["images"]]
            assert labels[0] == "Container Door Number"
            assert labels[1] == "Flexitank Serial Number"

    def test_accept_sets_status(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")

            response = client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )
            assert response.status_code == 200
            assert response.json()["status"] == "accepted"

    def test_reject_sets_status(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")

            response = client.post(
                f"/api/inspections/{inspection['id']}/reject",
                headers=_headers(manager_token),
            )
            assert response.status_code == 200
            assert response.json()["status"] == "rejected"

    def test_cannot_accept_already_accepted(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")

            client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )
            response = client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )
            assert response.status_code == 400

    def test_cannot_reject_already_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")

            client.post(
                f"/api/inspections/{inspection['id']}/reject",
                headers=_headers(manager_token),
            )
            response = client.post(
                f"/api/inspections/{inspection['id']}/reject",
                headers=_headers(manager_token),
            )
            assert response.status_code == 400

    def test_cannot_export_unaccepted_inspection(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")

            response = client.post(
                f"/api/inspections/{inspection['id']}/export-excel-email",
                headers=_headers(manager_token),
            )
            assert response.status_code == 400

    def test_404_on_nonexistent_inspection(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            manager_token = _login(client, "manager@example.com", "manager12345")
            response = client.get(
                "/api/inspections/00000000-0000-0000-0000-000000000000",
                headers=_headers(manager_token),
            )
            assert response.status_code == 404

    def test_list_filter_by_status(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token)
            manager_token = _login(client, "manager@example.com", "manager12345")
            client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )

            submitted = client.get(
                "/api/inspections",
                headers=_headers(manager_token),
                params={"status": "submitted"},
            )
            accepted = client.get(
                "/api/inspections",
                headers=_headers(manager_token),
                params={"status": "accepted"},
            )

            assert all(item["status"] == "submitted" for item in submitted.json())
            assert any(item["id"] == inspection["id"] for item in accepted.json())

    def test_wrong_image_count_rejected(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            response = client.post(
                "/api/inspections",
                headers=_headers(token),
                data={
                    "container_number": "TCLU1234565",
                    "flexitank_number": "23TT3-2601-005",
                    "booking_number": "BK-001",
                    "truck_number": "TR-001",
                    "worker_name": "W",
                    "port_name": "P",
                    "notes": "",
                },
                files=_image_files(count=5),
            )
            assert response.status_code == 400

    def test_container_number_uppercased(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            inspection = _create_inspection(
                client,
                token,
                container_number="tclu1234565",
            )
            assert inspection["container_number"] == "TCLU1234565"


class TestBookingNumber:
    def test_worker_can_submit_without_booking_number(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            inspection = _create_inspection(client, token, booking_number="")
            assert inspection["booking_number"] == ""
            assert inspection["status"] == "submitted"

    def test_accept_fails_without_booking_number(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token, booking_number="")
            manager_token = _login(client, "manager@example.com", "manager12345")

            response = client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )
            assert response.status_code == 400
            assert "booking number" in response.json()["detail"].lower()

    def test_manager_can_set_booking_number_then_accept(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token, booking_number="")
            manager_token = _login(client, "manager@example.com", "manager12345")

            update_response = client.patch(
                f"/api/inspections/{inspection['id']}/booking-number",
                headers=_headers(manager_token),
                json={"booking_number": "BK-NEW-001"},
            )
            assert update_response.status_code == 200, update_response.text
            assert update_response.json()["booking_number"] == "BK-NEW-001"

            accept_response = client.post(
                f"/api/inspections/{inspection['id']}/accept",
                headers=_headers(manager_token),
            )
            assert accept_response.status_code == 200, accept_response.text
            assert accept_response.json()["status"] == "accepted"
            assert accept_response.json()["booking_number"] == "BK-NEW-001"

    def test_worker_cannot_update_booking_number(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token, booking_number="")

            response = client.patch(
                f"/api/inspections/{inspection['id']}/booking-number",
                headers=_headers(worker_token),
                json={"booking_number": "BK-002"},
            )
            assert response.status_code == 403

    def test_update_booking_number_rejects_empty_value(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            worker_token = _register_worker(client)
            inspection = _create_inspection(client, worker_token, booking_number="BK-003")
            manager_token = _login(client, "manager@example.com", "manager12345")

            response = client.patch(
                f"/api/inspections/{inspection['id']}/booking-number",
                headers=_headers(manager_token),
                json={"booking_number": "   "},
            )
            assert response.status_code in (400, 422)

    def test_recent_booking_numbers_are_deduped_and_ordered(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            _create_inspection(client, token, booking_number="BK-100")
            _create_inspection(client, token, booking_number="BK-200")
            _create_inspection(client, token, booking_number="BK-100")

            response = client.get(
                "/api/inspections/booking-numbers/recent",
                headers=_headers(token),
            )
            assert response.status_code == 200, response.text
            numbers = response.json()["booking_numbers"]

            assert numbers[0] == "BK-100"
            assert numbers.count("BK-100") == 1
            assert "BK-200" in numbers

    def test_recent_booking_numbers_excludes_empty(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            _create_inspection(client, token, booking_number="")
            _create_inspection(client, token, booking_number="BK-300")

            response = client.get(
                "/api/inspections/booking-numbers/recent",
                headers=_headers(token),
            )
            assert response.status_code == 200, response.text
            numbers = response.json()["booking_numbers"]
            assert "" not in numbers
            assert "BK-300" in numbers


class TestExports:
    def _setup_accepted(self, client):
        worker_token = _register_worker(
            client,
            "export-worker@test.com",
            name="Export Worker",
        )
        inspection = _create_inspection(client, worker_token)
        manager_token = _login(client, "manager@example.com", "manager12345")
        response = client.post(
            f"/api/inspections/{inspection['id']}/accept",
            headers=_headers(manager_token),
        )
        assert response.status_code == 200, response.text
        return inspection, manager_token

    def test_excel_export_creates_file(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            inspection, manager_token = self._setup_accepted(client)
            response = client.post(
                f"/api/inspections/{inspection['id']}/export-excel-email",
                headers=_headers(manager_token),
            )

            assert response.status_code == 200, response.text
            data = response.json()
            assert data["status"] == "exported"
            assert data["filename"].endswith(".xlsx")
            assert Path(tmp_path / "reports" / inspection["id"] / data["filename"]).exists()

    def test_word_report_creates_file(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            inspection, manager_token = self._setup_accepted(client)
            response = client.post(
                f"/api/inspections/{inspection['id']}/generate-report-email",
                headers=_headers(manager_token),
            )

            assert response.status_code == 200, response.text
            data = response.json()
            assert data["status"] == "exported"
            assert data["filename"].endswith(".docx")
            assert Path(tmp_path / "reports" / inspection["id"] / data["filename"]).exists()

    def test_email_outbox_has_eml_files(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            inspection, manager_token = self._setup_accepted(client)
            response = client.post(
                f"/api/inspections/{inspection['id']}/export-excel-email",
                headers=_headers(manager_token),
            )

            assert response.status_code == 200, response.text
            assert list((tmp_path / "email_outbox").glob("*.eml"))


class TestOCR:
    def test_scan_container_returns_number(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            response = client.post(
                "/api/ai/scan-container-id",
                headers=_headers(token),
                files={"image": ("img.jpg", _jpeg_bytes(), "image/jpeg")},
            )
            assert response.status_code == 200
            assert response.json()["container_number"] == "TCLU1234565"

    def test_scan_flexitank_returns_number(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            token = _register_worker(client)
            response = client.post(
                "/api/ai/scan-flexitank-id",
                headers=_headers(token),
                files={"image": ("img.jpg", _jpeg_bytes(), "image/jpeg")},
            )
            assert response.status_code == 200
            assert response.json()["flexitank_number"] == "23TT3-2601-005"

    def test_scan_requires_auth(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.post(
                "/api/ai/scan-container-id",
                files={"image": ("img.jpg", _jpeg_bytes(), "image/jpeg")},
            )
            assert response.status_code == 401

    def test_scan_manager_cannot_access(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            manager_token = _login(client, "manager@example.com", "manager12345")
            response = client.post(
                "/api/ai/scan-container-id",
                headers=_headers(manager_token),
                files={"image": ("img.jpg", _jpeg_bytes(), "image/jpeg")},
            )
            assert response.status_code == 403

    def test_invalid_ocr_raises_422(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        inspection_routes = importlib.import_module("app.api.routes.inspection_routes")
        from app.services.ai.container_ocr import ContainerOcrError

        monkeypatch.setattr(
            inspection_routes,
            "detect_container_number",
            lambda image_path: (_ for _ in ()).throw(ContainerOcrError("no match")),
        )

        with TestClient(app) as client:
            token = _register_worker(client)
            response = client.post(
                "/api/ai/scan-container-id",
                headers=_headers(token),
                files={"image": ("img.jpg", _jpeg_bytes(), "image/jpeg")},
            )
            assert response.status_code == 422


class TestISO6346:
    def test_valid_container_numbers(self):
        from app.services.ai.container_ocr import is_valid_iso_6346

        assert is_valid_iso_6346("TCLU1234568")
        assert is_valid_iso_6346("MSCU6639870")

    def test_invalid_check_digit(self):
        from app.services.ai.container_ocr import is_valid_iso_6346

        assert not is_valid_iso_6346("TCLU1234560")

    def test_wrong_length(self):
        from app.services.ai.container_ocr import is_valid_iso_6346

        assert not is_valid_iso_6346("TCLU123456")
        assert not is_valid_iso_6346("TCLU12345678")

    def test_bad_format(self):
        from app.services.ai.container_ocr import is_valid_iso_6346

        assert not is_valid_iso_6346("1234567890A")


class TestMisc:
    def test_health_endpoint(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.get("/health")
            assert response.status_code == 200
            assert response.json()["status"] == "healthy"

    def test_root_endpoint(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.get("/")
            assert response.status_code == 200

    def test_config_photo_labels(self, tmp_path, monkeypatch):
        from fastapi.testclient import TestClient

        app = _fresh_app(tmp_path, monkeypatch)
        with TestClient(app) as client:
            response = client.get("/api/config")
            assert response.status_code == 200
            labels = response.json()["photo_labels"]
            assert len(labels) == 12
            assert "Container Door Number" in labels