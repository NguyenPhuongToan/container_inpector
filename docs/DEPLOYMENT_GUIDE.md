# Deployment Guide

## Required Services

- PostgreSQL
- FastAPI backend
- Flutter web/mobile frontend
- SMTP account, only if email delivery is needed

## Backend Environment

Create `backend_python/.env` from `.env.example`.

Important values:

- `DATABASE_URL`
- `JWT_SECRET`
- `JWT_EXPIRES_MINUTES`
- `WORKER_JWT_EXPIRES_MINUTES`
- `MANAGER_EMAIL`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM`
- `SMTP_USE_TLS`
- `EMAIL_DELIVERY_MODE`
- `EMAIL_OUTBOX_DIR`

## Local Backend

```powershell
cd backend_python
.\venv\Scripts\uvicorn.exe app.main:app --host 127.0.0.1 --port 8000
```

## Local Frontend

```powershell
cd frontend_flutter
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Notes Before Production

- Replace demo/default users with a controlled admin bootstrap.
- Require a real `JWT_SECRET`.
- Restrict CORS origins.
- Add database migrations.
- Add backup and restore procedures.
