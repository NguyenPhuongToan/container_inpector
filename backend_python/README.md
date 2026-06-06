# Backend

FastAPI backend for the Container Inspection System.

## Run Locally

Start PostgreSQL first. With Docker Desktop:

```powershell
docker compose up -d postgres
```

Install dependencies:

```powershell
python -m venv venv
.\venv\Scripts\pip install -r requirements.txt
```

The fitting photo PowerPoint export uses
`templates/fitting_photo_template.pptx` by default. Override it with
`FITTING_PHOTO_TEMPLATE_PATH` if the company template is stored elsewhere.

Start the API:

```powershell
.\venv\Scripts\uvicorn.exe app.main:app --host 127.0.0.1 --port 8000
```

Health check:

```text
http://127.0.0.1:8000/health
```

## Test

```powershell
.\venv\Scripts\pytest.exe
```

The full-flow test uses a temporary SQLite database, local generated images,
patched OCR, and the email outbox mode.
