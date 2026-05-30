# API Documentation

Base path: `/api`

## Auth

- `POST /auth/login`
  - Logs in an existing user.
  - Returns a bearer token and user profile.

- `POST /auth/register-worker`
  - Creates a new worker account.
  - Always assigns `role = worker`.
  - Returns a bearer token and user profile.

## Inspections

- `POST /inspections`
  - Roles: `worker`, `admin`
  - Creates an inspection with 14 required images.

- `GET /inspections`
  - Roles: authenticated users
  - Workers only see their own inspections.
  - Managers/admins can see all matching inspections.
  - Optional filters: `status`, `container_number`, `worker_name`,
    `port_name`.

- `GET /inspections/{inspection_id}`
  - Roles: authenticated users
  - Workers can only open their own inspections.

- `POST /inspections/{inspection_id}/accept`
  - Roles: `manager`, `admin`
  - Marks an inspection as accepted.

- `POST /inspections/{inspection_id}/reject`
  - Roles: `manager`, `admin`
  - Marks an inspection as rejected.

## OCR

- `POST /ai/scan-container-id`
  - Roles: `worker`, `admin`
  - Accepts one image and returns a detected container number.

## Reports

- `POST /inspections/{inspection_id}/export-excel-email`
  - Roles: `manager`, `admin`
  - Requires accepted inspection.
  - Generates an Excel report and attempts to email it.

- `POST /inspections/{inspection_id}/generate-report-email`
  - Roles: `manager`, `admin`
  - Requires accepted inspection.
  - Generates a Word photo report and attempts to email it.
