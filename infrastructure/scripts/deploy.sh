#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend_python"

cd "$BACKEND_DIR"

docker compose up -d postgres

if [[ ! -d "venv" ]]; then
  python -m venv venv
fi

"$BACKEND_DIR/venv/Scripts/python.exe" -m pip install -r requirements.txt
"$BACKEND_DIR/venv/Scripts/python.exe" -m compileall app

echo "Backend dependencies installed. Start the API with:"
echo "  ./venv/Scripts/uvicorn.exe app.main:app --host 127.0.0.1 --port 8000"
