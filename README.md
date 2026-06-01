# Container Inspection System

AI-assisted container inspection app with a FastAPI backend and Flutter
frontend.

## What The App Does

- Workers register or log in.
- Workers submit container inspections with 14 required photos.
- The first photo can be scanned for a container number using OCR.
- Managers review submitted inspections.
- Managers accept or reject inspections.
- Accepted inspections can be exported to Excel or a Word photo report.
- Reports can be emailed when SMTP settings are configured.

## Main Folders

- `backend_python/` - FastAPI backend, database models, auth, OCR, reports.
- `frontend_flutter/` - Flutter mobile/web app.
- `docs/` - project documentation.
- `infrastructure/` - deployment, nginx, monitoring, and helper scripts.
- `shared/` - reserved for shared assets or contracts.

## Local Tools Needed

- PostgreSQL running on port `5432`, or update `DATABASE_URL`.
- Python virtual environment for the backend.
- Flutter SDK for the frontend.
- Chrome for Flutter web demos.
- Docker Desktop is optional if you want to run Postgres from
  `backend_python/docker-compose.yml`.

## Backend Setup

Create `backend_python/.env` from `backend_python/.env.example`, then fill in
the database and secret values.

Minimum demo values:

```env
DATABASE_URL=postgresql+psycopg://postgres:YOUR_PASSWORD@localhost:5432/container_inspection
JWT_SECRET=replace_this_with_a_long_random_secret
JWT_EXPIRES_MINUTES=1440
MANAGER_EMAIL=manager@example.com
```

Run the backend from `backend_python`:

```powershell
.\venv\Scripts\uvicorn.exe app.main:app --host 127.0.0.1 --port 8000
```

Health check:

```text
http://127.0.0.1:8000/health
```

## Frontend Setup

Run the frontend from `frontend_flutter`:

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Current Role Model

- `worker` - can register, submit inspections, scan container IDs, and view
  their own history.
- `manager` - can review, accept, reject, export, and email accepted
  inspections.
- `admin` - can access both worker and manager workflows.

## Local Test Accounts

When `SEED_DEMO_USERS=true`, the backend creates these accounts at startup:

- `worker@example.com / worker12345`
- `manager@example.com / manager12345`
- `admin@example.com / admin12345`
