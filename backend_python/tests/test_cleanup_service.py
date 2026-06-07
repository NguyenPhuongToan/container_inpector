import os
from datetime import datetime, timedelta, timezone


def test_cleanup_old_files_keeps_generated_reports(tmp_path, monkeypatch):
    from app.services.storage import cleanup_service

    ocr_root = tmp_path / "ocr"
    report_root = tmp_path / "reports"
    ocr_root.mkdir()
    report_root.mkdir()

    old_ocr_file = ocr_root / "scan.jpg"
    old_report_file = report_root / "inspection.xlsx"
    old_ocr_file.write_text("temporary scan")
    old_report_file.write_text("manager report")

    old_timestamp = (
        datetime.now(timezone.utc) - timedelta(hours=25)
    ).timestamp()
    os.utime(old_ocr_file, (old_timestamp, old_timestamp))
    os.utime(old_report_file, (old_timestamp, old_timestamp))

    monkeypatch.setattr(cleanup_service, "OCR_TEMP_ROOT", ocr_root)

    assert cleanup_service.cleanup_old_files() == 1
    assert not old_ocr_file.exists()
    assert old_report_file.exists()
