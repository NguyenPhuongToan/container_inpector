#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
CONTAINER_NAME="${POSTGRES_CONTAINER:-container_inspection_postgres}"
DATABASE_NAME="${POSTGRES_DB:-container_inspection}"
DATABASE_USER="${POSTGRES_USER:-postgres}"

mkdir -p "$BACKUP_DIR"

timestamp="$(date +%Y%m%d_%H%M%S)"
backup_path="$BACKUP_DIR/${DATABASE_NAME}_${timestamp}.sql"

docker exec "$CONTAINER_NAME" pg_dump -U "$DATABASE_USER" "$DATABASE_NAME" > "$backup_path"

echo "Backup written to $backup_path"
