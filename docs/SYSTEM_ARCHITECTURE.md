# System Architecture

## Overview

The system has three main parts:

```text
Flutter app
→ FastAPI backend
→ PostgreSQL database
```

The backend also stores uploaded inspection photos and generated reports on the
local filesystem.

## Frontend

The Flutter app handles:

- Login and worker registration
- Role-based home screen
- Worker inspection submission
- Worker history
- Manager review dashboard
- Accept/reject actions
- Export/report actions

## Backend

The FastAPI backend handles:

- JWT authentication
- Role checks
- Worker registration
- Inspection creation
- Image upload validation/storage
- OCR container number scanning
- Manager review actions
- Excel report generation
- Word photo report generation
- Email sending

## Storage

- Inspection photos: `backend_python/uploads/inspections/`
- Generated reports: `backend_python/reports/`
- Temporary OCR images: `backend_python/tmp/ocr_scans/`

## Roles

- Worker: submit inspections and view own history.
- Manager: review, accept/reject, export accepted inspections.
- Admin: both worker and manager capabilities.

## Future Refactor Direction

Several service folders already exist. A clean next step is to move large logic
out of `inspection_routes.py` into focused services:

- image storage
- Excel export
- Word report generation
- email notification
- cleanup workers
