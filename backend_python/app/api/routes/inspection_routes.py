import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import UploadFile as StarletteUploadFile

from app.api.dependencies import get_current_user, require_roles
from app.core.constants import OCR_TEMP_ROOT, PHOTO_LABELS as SHARED_PHOTO_LABELS, REPORT_ROOT, UPLOAD_ROOT
from app.database.db import get_db
from app.database.models import ExportRecord, Inspection, InspectionImage, User
from app.schemas.inspection_schema import (
    ExportEmailResponse,
    FittingPhotoExportRequest,
    InspectionResponse,
    ScanContainerIdResponse,
    ScanFlexitankIdResponse,
)
from app.services.ai.container_ocr import (
    ContainerOcrError,
    FlexitankOcrError,
    detect_container_number,
    detect_flexitank_number,
)
from app.services.excel.excel_exporter import ExcelExportError, generate_excel
from app.services.excel.template_manager import WordReportError, generate_word_report
from app.services.notification.email_service import (
    EmailConfigurationError,
    send_email_with_attachment,
)
from app.services.presentation.fitting_photo_exporter import (
    FittingPhotoExportError,
    generate_fitting_photo_pptx,
)
from app.services.storage.image_storage import save_upload, validate_image

router = APIRouter(tags=["inspections"])

PHOTO_LABELS = list(SHARED_PHOTO_LABELS)


def _ensure_storage() -> None:
    UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    OCR_TEMP_ROOT.mkdir(parents=True, exist_ok=True)


def _public_url(request: Request, path: str) -> str:
    return str(request.base_url).rstrip("/") + "/" + path.lstrip("/")


def _inspection_to_dict(inspection: Inspection) -> dict[str, Any]:
    images = [
        {
            "angle": image.angle,
            "label": image.label,
            "url": image.url,
        }
        for image in sorted(inspection.images, key=lambda item: item.angle)
    ]
    return {
        "id": inspection.id,
        "container_number": inspection.container_number,
        "flexitank_number": inspection.flexitank_number or "",
        "booking_number": inspection.booking_number,
        "truck_number": inspection.truck_number,
        "worker_name": inspection.worker_name,
        "port_name": inspection.port_name,
        "notes": inspection.notes or "",
        "status": inspection.status,
        "created_at": inspection.created_at.isoformat(),
        "updated_at": inspection.updated_at.isoformat(),
        "image_urls": [image["url"] for image in images],
        "images": images,
    }


def _find_inspection(db: Session, inspection_id: str) -> Inspection:
    inspection = db.scalar(
        select(Inspection)
        .options(selectinload(Inspection.images))
        .where(Inspection.id == inspection_id)
    )

    if inspection is not None:
        return inspection

    raise HTTPException(status_code=404, detail="Inspection not found")


def _safe_label(label: str) -> str:
    return re.sub(r"[^a-z0-9_]+", "_", label.lower()).strip("_")


async def _extract_inspection_images(request: Request) -> list[UploadFile]:
    form = await request.form()
    indexed_images: list[UploadFile] = []

    for index in range(len(PHOTO_LABELS)):
        file_obj = form.get(f"image_{index}")

        if not isinstance(file_obj, StarletteUploadFile):
            indexed_images = []
            break

        indexed_images.append(file_obj)

    if len(indexed_images) == len(PHOTO_LABELS):
        return indexed_images

    repeated_images = [
        file_obj
        for file_obj in form.getlist("images")
        if isinstance(file_obj, StarletteUploadFile)
    ]

    if len(repeated_images) == len(PHOTO_LABELS):
        return repeated_images

    bracket_images = [
        file_obj
        for file_obj in form.getlist("images[]")
        if isinstance(file_obj, StarletteUploadFile)
    ]

    if len(bracket_images) == len(PHOTO_LABELS):
        return bracket_images

    raise HTTPException(
        status_code=400,
        detail=(
            f"Expected {len(PHOTO_LABELS)} classified photos using "
            "image_0 through image_13."
        ),
    )


@router.post(
    "/inspections",
    status_code=201,
    response_model=InspectionResponse,
)
async def create_inspection(
    request: Request,
    container_number: str = Form(...),
    flexitank_number: str = Form(""),
    booking_number: str = Form(""),
    truck_number: str = Form(...),
    worker_name: str = Form(...),
    port_name: str = Form(...),
    notes: str = Form(""),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("worker", "admin")),
):
    images = await _extract_inspection_images(request)

    if len(images) != len(PHOTO_LABELS):
        raise HTTPException(
            status_code=400,
            detail=f"Expected {len(PHOTO_LABELS)} images, received {len(images)}",
        )

    _ensure_storage()

    inspection_id = str(uuid4())
    inspection_dir = UPLOAD_ROOT / inspection_id
    inspection_dir.mkdir(parents=True, exist_ok=True)

    image_urls: list[str] = []
    image_records: list[dict[str, Any]] = []

    for index, image in enumerate(images):
        suffix = validate_image(image)
        safe_label = _safe_label(PHOTO_LABELS[index])
        filename = f"{index + 1:02d}_{safe_label}{suffix}"
        file_path = inspection_dir / filename

        await run_in_threadpool(save_upload, image, file_path)

        relative_path = f"uploads/inspections/{inspection_id}/{filename}"
        image_urls.append(_public_url(request, relative_path))
        image_records.append(
            {
                "angle": index + 1,
                "label": PHOTO_LABELS[index],
                "url": _public_url(request, relative_path),
                "path": str(file_path),
            }
        )

    inspection = Inspection(
        id=inspection_id,
        container_number=container_number.strip().upper(),
        flexitank_number=flexitank_number.strip().upper(),
        booking_number=booking_number.strip(),
        truck_number=truck_number.strip(),
        worker_name=worker_name.strip() or current_user.full_name,
        port_name=port_name.strip(),
        notes=notes.strip(),
        status="submitted",
        worker_id=current_user.id,
    )
    db.add(inspection)

    for image_record in image_records:
        db.add(
            InspectionImage(
                inspection_id=inspection_id,
                angle=image_record["angle"],
                label=image_record["label"],
                url=image_record["url"],
                path=image_record["path"],
            )
        )

    db.commit()
    db.refresh(inspection)
    inspection = _find_inspection(db, inspection_id)
    return _inspection_to_dict(inspection)


@router.get("/inspections", response_model=list[InspectionResponse])
async def list_inspections(
    status: str | None = None,
    container_number: str | None = None,
    worker_name: str | None = None,
    port_name: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(Inspection).options(selectinload(Inspection.images))
    if status:
        query = query.where(Inspection.status == status.lower())
    if container_number:
        query = query.where(Inspection.container_number.ilike(f"%{container_number}%"))
    if worker_name:
        query = query.where(Inspection.worker_name.ilike(f"%{worker_name}%"))
    if port_name:
        query = query.where(Inspection.port_name.ilike(f"%{port_name}%"))
    if current_user.role == "worker":
        query = query.where(Inspection.worker_id == current_user.id)

    query = query.order_by(Inspection.created_at.desc())
    inspections = db.scalars(query).all()
    return [_inspection_to_dict(inspection) for inspection in inspections]


@router.get("/inspections/{inspection_id}", response_model=InspectionResponse)
async def get_inspection(
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    inspection = _find_inspection(db, inspection_id)
    if current_user.role == "worker" and inspection.worker_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not allowed")
    return _inspection_to_dict(inspection)


@router.post(
    "/inspections/{inspection_id}/accept",
    response_model=InspectionResponse,
)
async def accept_inspection(
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    inspection = _find_inspection(db, inspection_id)
    _ensure_submitted(inspection)
    inspection.status = "accepted"
    inspection.accepted_by_id = current_user.id
    inspection.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(inspection)
    inspection = _find_inspection(db, inspection_id)
    return _inspection_to_dict(inspection)


@router.post(
    "/inspections/{inspection_id}/reject",
    response_model=InspectionResponse,
)
async def reject_inspection(
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    inspection = _find_inspection(db, inspection_id)
    _ensure_submitted(inspection)
    inspection.status = "rejected"
    inspection.rejected_by_id = current_user.id
    inspection.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(inspection)
    inspection = _find_inspection(db, inspection_id)
    return _inspection_to_dict(inspection)


def _ensure_accepted(inspection: Inspection) -> None:
    if inspection.status != "accepted":
        raise HTTPException(
            status_code=400,
            detail="Only accepted inspections can be exported",
        )


def _report_url_for_path(request: Request, report_path: Path) -> str:
    try:
        relative_path = report_path.relative_to(REPORT_ROOT)
    except ValueError:
        relative_path = Path(report_path.name)
    return _public_url(request, f"reports/{relative_path.as_posix()}")


def _find_accepted_booking_group(db: Session, inspection: Inspection) -> list[Inspection]:
    group = db.scalars(
        select(Inspection)
        .options(selectinload(Inspection.images))
        .where(Inspection.booking_number == inspection.booking_number)
        .where(Inspection.status == "accepted")
        .order_by(Inspection.created_at.asc())
    ).all()

    return list(group)


def _find_selected_accepted_inspections(
    db: Session,
    inspection_ids: list[str],
) -> list[Inspection]:
    unique_ids = list(dict.fromkeys(inspection_ids))
    inspections = db.scalars(
        select(Inspection)
        .options(selectinload(Inspection.images))
        .where(Inspection.id.in_(unique_ids))
    ).all()
    inspections_by_id = {inspection.id: inspection for inspection in inspections}

    missing_ids = [
        inspection_id
        for inspection_id in unique_ids
        if inspection_id not in inspections_by_id
    ]
    if missing_ids:
        raise HTTPException(status_code=404, detail="One or more inspections were not found")

    selected = [inspections_by_id[inspection_id] for inspection_id in unique_ids]
    for inspection in selected:
        _ensure_accepted(inspection)

    booking_numbers = {
        inspection.booking_number.strip().lower()
        for inspection in selected
    }
    if len(booking_numbers) > 1:
        raise HTTPException(
            status_code=400,
            detail="Selected inspections must share the same booking number",
        )

    return selected


def _ensure_submitted(inspection: Inspection) -> None:
    if inspection.status != "submitted":
        raise HTTPException(
            status_code=400,
            detail="Only submitted inspections can be accepted or rejected",
        )


def _email_attachment(
    *,
    inspection: dict[str, Any],
    attachment_path: Path,
    export_label: str,
) -> tuple[bool, str | None, str]:
    subject = f"{export_label} - {inspection['container_number']}"
    body = (
        "Please find the attached container inspection file.\n\n"
        f"Container Number: {inspection['container_number']}\n"
        f"Flexitank Number: {inspection['flexitank_number']}\n"
        f"Booking Number: {inspection['booking_number']}\n"
        f"Truck Number: {inspection['truck_number']}\n"
        f"Status: {inspection['status']}\n"
    )

    try:
        result = send_email_with_attachment(
            subject=subject,
            body=body,
            attachment_path=attachment_path,
        )
    except EmailConfigurationError:
        return False, None, "Email settings are not configured yet."
    except Exception as exc:
        return False, None, f"Email sending failed: {exc}"

    return bool(result["sent"]), str(result["to"]), "Email sent successfully."


def _export_response(
    *,
    request: Request,
    inspection: Inspection,
    report_path: Path,
    export_label: str,
    export_type: str,
    db: Session,
) -> dict[str, Any]:
    inspection_data = _inspection_to_dict(inspection)
    email_sent, email_to, email_message = _email_attachment(
        inspection=inspection_data,
        attachment_path=report_path,
        export_label=export_label,
    )
    report_url = _public_url(request, f"reports/{inspection.id}/{report_path.name}")

    db.add(
        ExportRecord(
            inspection_id=inspection.id,
            export_type=export_type,
            filename=report_path.name,
            report_url=report_url,
            email_sent=email_sent,
            email_to=email_to,
            message=email_message,
        )
    )
    db.commit()

    return {
        "status": "exported",
        "message": f"{export_label} generated. {email_message}",
        "report_url": report_url,
        "email_sent": email_sent,
        "email_to": email_to,
        "filename": report_path.name,
    }


def _fitting_photo_export_response(
    *,
    request: Request,
    booking_group: list[Inspection],
    report_path: Path,
    db: Session,
) -> dict[str, Any]:
    primary_inspection = booking_group[0]
    inspection_data = _inspection_to_dict(primary_inspection)
    email_sent, email_to, email_message = _email_attachment(
        inspection=inspection_data,
        attachment_path=report_path,
        export_label="Fitting photo PowerPoint",
    )
    report_url = _report_url_for_path(request, report_path)

    for group_item in booking_group:
        db.add(
            ExportRecord(
                inspection_id=group_item.id,
                export_type="fitting_photo_pptx",
                filename=report_path.name,
                report_url=report_url,
                email_sent=email_sent,
                email_to=email_to,
                message=email_message,
            )
        )
    db.commit()

    return {
        "status": "exported",
        "message": (
            f"Fitting photo PowerPoint generated for booking "
            f"{primary_inspection.booking_number} with {len(booking_group)} container(s). {email_message}"
        ),
        "report_url": report_url,
        "email_sent": email_sent,
        "email_to": email_to,
        "filename": report_path.name,
    }


@router.post(
    "/inspections/{inspection_id}/export-excel-email",
    response_model=ExportEmailResponse,
)
async def export_excel_and_email(
    request: Request,
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    inspection = _find_inspection(db, inspection_id)
    _ensure_accepted(inspection)
    _ensure_storage()

    try:
        report_path = generate_excel(inspection)
    except ExcelExportError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return _export_response(
        request=request,
        inspection=inspection,
        report_path=report_path,
        export_label="Excel export",
        export_type="excel",
        db=db,
    )


@router.post(
    "/inspections/{inspection_id}/generate-report-email",
    response_model=ExportEmailResponse,
)
async def generate_report_and_email(
    request: Request,
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    inspection = _find_inspection(db, inspection_id)
    _ensure_accepted(inspection)
    _ensure_storage()

    try:
        report_path = generate_word_report(inspection, request)
    except WordReportError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return _export_response(
        request=request,
        inspection=inspection,
        report_path=report_path,
        export_label="Photo report",
        export_type="photo_report",
        db=db,
    )


@router.post(
    "/inspections/export-fitting-photo-email",
    response_model=ExportEmailResponse,
)
async def export_selected_fitting_photos_and_email(
    request: Request,
    payload: FittingPhotoExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    _ensure_storage()
    booking_group = _find_selected_accepted_inspections(db, payload.inspection_ids)

    try:
        report_path = await run_in_threadpool(generate_fitting_photo_pptx, booking_group)
    except FittingPhotoExportError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return _fitting_photo_export_response(
        request=request,
        booking_group=booking_group,
        report_path=report_path,
        db=db,
    )


@router.post(
    "/inspections/{inspection_id}/export-fitting-photo-email",
    response_model=ExportEmailResponse,
)
async def export_fitting_photo_and_email(
    request: Request,
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    inspection = _find_inspection(db, inspection_id)
    _ensure_accepted(inspection)
    _ensure_storage()

    booking_group = _find_accepted_booking_group(db, inspection)
    if not booking_group:
        raise HTTPException(status_code=400, detail="No accepted inspections found for this booking")

    try:
        report_path = await run_in_threadpool(generate_fitting_photo_pptx, booking_group)
    except FittingPhotoExportError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return _fitting_photo_export_response(
        request=request,
        booking_group=booking_group,
        report_path=report_path,
        db=db,
    )


@router.post(
    "/inspections/{inspection_id}/export-email",
    response_model=ExportEmailResponse,
)
async def export_and_email_inspection(
    request: Request,
    inspection_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles("manager", "admin")),
):
    return await export_excel_and_email(request, inspection_id, db, current_user)


@router.post("/ai/scan-container-id", response_model=ScanContainerIdResponse)
async def scan_container_id(
    image: UploadFile = File(...),
    current_user: User = Depends(require_roles("worker", "admin")),
):
    suffix = validate_image(image)
    _ensure_storage()

    temp_path = OCR_TEMP_ROOT / f"{uuid4()}{suffix}"
    await run_in_threadpool(save_upload, image, temp_path)

    try:
        container_number = await run_in_threadpool(detect_container_number, temp_path)
    except ContainerOcrError:
        raise HTTPException(
            status_code=422,
            detail="Container number could not be detected from this image",
        )
    finally:
        temp_path.unlink(missing_ok=True)

    return {"container_number": container_number}


@router.post("/ai/scan-flexitank-id", response_model=ScanFlexitankIdResponse)
async def scan_flexitank_id(
    image: UploadFile = File(...),
    current_user: User = Depends(require_roles("worker", "admin")),
):
    suffix = validate_image(image)
    _ensure_storage()

    temp_path = OCR_TEMP_ROOT / f"{uuid4()}{suffix}"
    await run_in_threadpool(save_upload, image, temp_path)

    try:
        flexitank_number = await run_in_threadpool(detect_flexitank_number, temp_path)
    except FlexitankOcrError:
        raise HTTPException(
            status_code=422,
            detail="Flexitank serial number could not be detected from this image",
        )
    finally:
        temp_path.unlink(missing_ok=True)

    return {"flexitank_number": flexitank_number}