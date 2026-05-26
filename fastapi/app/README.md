# Chembience FastAPI Application

This is the async REST API service for your Chembience project. It is built using FastAPI and integrated with RDKit for chemical informatics.

## Directory Structure

- `src/`: The main FastAPI project directory.
- `fastapi-init`: Helper script for initializing the application.
- `db_backup`, `db_cleanup`, `db_restore`: Database management scripts.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

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
