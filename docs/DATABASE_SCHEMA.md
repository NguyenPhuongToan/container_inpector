# Database Schema

The backend uses SQLAlchemy models in
`backend_python/app/database/models.py`.

## users

Stores all authenticated people, including workers, managers, and admins.

- `id`
- `email`
- `full_name`
- `role`
- `password_hash`
- `is_active`
- `created_at`

## inspections

Stores submitted container inspections.

- `id`
- `container_number`
- `booking_number`
- `truck_number`
- `worker_name`
- `port_name`
- `notes`
- `status`
- `worker_id`
- `accepted_by_id`
- `rejected_by_id`
- `created_at`
- `updated_at`

Statuses currently used:

- `submitted`
- `accepted`
- `rejected`

## inspection_images

Stores metadata for each inspection photo.

- `id`
- `inspection_id`
- `angle`
- `label`
- `url`
- `path`

## export_records

Stores generated report/email attempts.

- `id`
- `inspection_id`
- `export_type`
- `filename`
- `report_url`
- `email_sent`
- `email_to`
- `message`
- `created_at`
