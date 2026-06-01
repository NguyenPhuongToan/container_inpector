#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8000/health}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-60}"

while true; do
  timestamp="$(date --iso-8601=seconds)"
  if python "$(dirname "$0")/healthcheck.py" "$HEALTH_URL" >/dev/null; then
    echo "$timestamp healthy"
  else
    echo "$timestamp unhealthy"
  fi
  sleep "$INTERVAL_SECONDS"
done
