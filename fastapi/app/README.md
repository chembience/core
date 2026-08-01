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

## Dev-to-Prod Promotion

Use this workflow when your project is ready to run with `CHEMBIENCE_RUNTIME_MODE=prod`.

1. Keep developing and testing in `dev` mode.
2. Run:

```bash
./fastapi-prepare-prod
```

What the script does:
- Creates a fresh `./.env.prod` from `./.env`.
- Forces `CHEMBIENCE_RUNTIME_MODE=prod` in `./.env.prod`.
- Applies it through `./fastapi-configure ./.env.prod` (password rotation + service refresh when needed).
- Validates compose config and checks `http://localhost:${FASTAPI_CONNECTION_PORT:-8002}/healthz`.

Optional flags:
- `--rebuild` → passes through to `fastapi-configure --rebuild`.
- `--keep-env-prod` → reuses existing `./.env.prod`.

Recommended post-promotion checks:

```bash
docker compose --env-file ./.env ps
curl -fsS "http://localhost:${FASTAPI_CONNECTION_PORT:-8002}/healthz"
docker compose --env-file ./.env exec -T fastapi python -c "import main; print('main import ok')"
```

Current Phase 2 caveat:
- FastAPI is the most production-friendly service right now, including a fallback to baked `/fastapi/src` if `/home/app/src/main.py` is absent in `prod`.
- For strict immutability, prefer a dedicated release image with your final app code and pinned tags.
