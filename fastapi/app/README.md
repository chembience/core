# Chembience FastAPI Application

This is the async REST API service for your Chembience project. It is built using FastAPI and integrated with RDKit for chemical informatics.

## Directory Structure

- `src/`: The main FastAPI project directory.
- `fastapi-init`: Initializes the application and applies Alembic migrations.
- `fastapi-makemigrations`, `fastapi-migrate`: Django-style schema migration helpers.
- `db_backup`, `db_cleanup`, `db_restore`: Database management scripts.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

To start the FastAPI service along with the PostgreSQL database:

```bash
docker compose up -d
```

For initial setup:

```bash
./fastapi-init
```

## Database migrations

FastAPI uses Alembic to version the SQLAlchemy schema. After changing a model,
generate and review a migration, then apply it:

```bash
./fastapi-makemigrations "add molecular formula"
./fastapi-migrate
```

These correspond to Django's `makemigrations` and `migrate`. Migration files
are committed under `src/alembic/versions/`. FastAPI workers never modify the
schema during application startup.

To run tests:
```bash
docker compose exec fastapi pytest
```

The test suite creates a uniquely named disposable PostgreSQL database, applies
all migrations, and removes only that database after the test session.

For more information, see the root [README.md](../../README.md).

## Configuration

- Use `./fastapi-configure [--rebuild] [NEW_ENV_FILE]` to manage environment updates safely.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image that does not depend on bind mounts.

Prerequisite:
- The base core image must exist locally: `chembience/core-fastapi:${CHEMBIENCE_VERSION}` from your app `.env` (for example, run `./build` from repository root first).

```bash
./fastapi-prepare-prod
```

What the script does:
- Creates/reuses `./.env.prod` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Uses a clear production image name: `chembience/core-fastapi-prod-<app_name>:<tag>`.
- Verifies the image contains `/home/app/src/main.py`.
- Does **not** run `fastapi-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `./.env.prod`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

Examples:

```bash
# Repeatable release image build
./fastapi-prepare-prod --image-tag 0.6.0-fastapi.1

# Custom production image repository/name
./fastapi-prepare-prod --image-name registry.example.com/chem/fastapi-prod --image-tag 0.6.0-fastapi.1
```

Run the produced image (example):

```bash
docker run --rm -p 8002:8000 chembience/core-fastapi-prod-app:0.6.0-fastapi.1 \
  sh -c "alembic upgrade head && exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2"
```

For orchestrated deployments, run `alembic upgrade head` as a one-shot release
step before starting or replacing API workers, rather than once per replica.

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.
