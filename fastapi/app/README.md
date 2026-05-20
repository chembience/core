# Chembience FastAPI Application

This is the web service for your Chembience project. It is built using FastAPI and integrated with SQLAlchemy and RDKit.

## Directory Structure

- `apisite/`: The FastAPI application code.
  - `main.py`: The entry point for the FastAPI application.
  - `db/`: Database models and configuration.
- `psql`: Helper script for accessing the PostgreSQL database.
- `db_backup`: Script to create a database backup.
- `db_restore`: Script to restore a database from a backup.
- `db_cleanup`: Script to clean up (drop and recreate) the database.
- `fastapi-init`: Script to recreate the database schema for the FastAPI application.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

To run the FastAPI application along with its dependencies (like PostgreSQL):
```bash
docker compose up
```

Alternatively, to run FastAPI manually inside the container (e.g., for development with auto-reload):
```bash
docker compose exec fastapi uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
(Note: `uvicorn` is started in the `apisite` directory)

To access the database:
```bash
./psql
```

## Running Tests

To run the RDKit-PostgreSQL integration tests:
```bash
docker compose exec fastapi pytest
```
