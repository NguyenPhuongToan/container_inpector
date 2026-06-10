#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend_python"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_PYTHON="$BACKEND_DIR/venv/bin/python"
VENV_UVICORN="$BACKEND_DIR/venv/bin/uvicorn"

cd "$BACKEND_DIR"

docker compose up -d postgres

if [[ ! -d "venv" ]]; then
  "$PYTHON_BIN" -m venv venv
fi

"$VENV_PYTHON" -m pip install --upgrade pip
"$VENV_PYTHON" -m pip install -r requirements.txt
"$VENV_PYTHON" -m compileall app

echo "Backend dependencies installed. Start the API with:"
echo "  $VENV_UVICORN app.main:app --host 127.0.0.1 --port 8000"
