#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR/backend_python"
docker compose up -d postgres

if command -v pm2 >/dev/null 2>&1; then
  pm2 startOrReload ecosystem.config.js
else
  echo "Postgres restarted. PM2 is not installed, so start the backend manually:"
  echo "  ./venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000"
fi
