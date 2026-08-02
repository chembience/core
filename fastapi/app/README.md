# Chembience FastAPI Application

This is the async REST API service for your Chembience project. It is built using FastAPI and integrated with RDKit for chemical informatics.

## Directory Structure

- `src/`: The main FastAPI project directory.
- `fastapi-init`: Helper script for initializing the application.
- `db_backup`, `db_cleanup`, `db_restore`: Database management scripts.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

To start the FastAPI service along with the PostgreSQL database:

```bash
docker compose up -d
```

For initial setup (optional):

```bash
./fastapi-init
```

To run tests:
```bash
docker compose exec fastapi pytest
```

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
  sh -c "exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2"
```

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.
