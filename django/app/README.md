# Chembience Django Application

This is the web service for your Chembience project. It is built using Django and integrated with RDKit for chemical informatics.

## Directory Structure

- `src/`: The main Django project directory.
- `django-init`: Helper script for initializing the application.
- `django-manage-py`: Wrapper for Django's `manage.py`.
- `psql`: Helper script for accessing the PostgreSQL database.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

To start the Django service along with the PostgreSQL database:

```bash
docker compose up -d
```


For initial setup (optional):

```bash
./django-init
```

To run Django management commands:
```bash
docker compose exec django python manage.py <command>
```

or as a shortcut
```bash
./django-manage-py <command>
```

To access the database:
```bash
./psql
```

For more information, see the root [README.md](../../README.md).

## Configuration

- Use `./django-configure [--rebuild] [NEW_ENV_FILE]` to manage environment updates safely.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes (handles password rotation, migrations, superuser check).
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Promotion

Use this workflow when your project is ready to run with `CHEMBIENCE_RUNTIME_MODE=prod`.

1. Keep developing in `dev` mode until your app is stable.
2. Run the promotion helper:

```bash
./django-prepare-prod
```

What the script does:
- Creates a fresh `./.env.prod` from `./.env`.
- Forces `CHEMBIENCE_RUNTIME_MODE=prod` in `./.env.prod`.
- Applies it through `./django-configure ./.env.prod` (DB password rotation, service refresh, migrations, superuser check).
- Runs `docker compose config` and a lightweight `/healthz` probe.

Optional flags:
- `--rebuild` → passes through to `django-configure --rebuild`.
- `--keep-env-prod` → reuses existing `./.env.prod` instead of recreating it.

Recommended checks after promotion:

```bash
docker compose --env-file ./.env ps
docker compose --env-file ./.env exec -T django python manage.py showmigrations
curl -fsS "http://localhost:${DJANGO_CONNECTION_PORT:-8001}/healthz"
```

Important caveat for current Phase 2 state:
- In `prod`, Django entrypoint no longer bootstraps project files and fails fast when `/home/app/src/manage.py` is missing.
- Keep `src/` fully initialized before promotion, or use a production image workflow that bakes project code.
