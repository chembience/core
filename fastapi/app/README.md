# Chembience FastAPI Application

This is the web service for your Chembience project. It is built using FastAPI and integrated with SQLAlchemy and RDKit.

## Directory Structure

- `main.py`: The entry point for the FastAPI application.
- `fastapi-init`: Helper script for initializing the application.
- `fastapi-run`: Helper script for running uvicorn commands.
- `psql`: Helper script for accessing the PostgreSQL database.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

To run FastAPI:
```bash
docker compose exec fastapi uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

or as a shortcut
```bash
./fastapi-run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

To access the database:
```bash
./psql
```
