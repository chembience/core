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

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image that includes your Django project source.

Prerequisite:
- The base core image must exist locally: `chembience/core-django:${CHEMBIENCE_VERSION}` from your app `.env` (for example, run `./build` from repository root first).

```bash
./django-prepare-prod
```

What the script does:
- Creates/reuses `./.env.prod` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Uses a clear production image name: `chembience/core-django-prod-<app_name>:<tag>`.
- Verifies the image contains `/home/app/src/manage.py`.
- Does **not** run `django-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `./.env.prod`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

Examples:

```bash
# Repeatable release image build
./django-prepare-prod --image-tag 0.6.0-django.1

# Custom production image repository/name
./django-prepare-prod --image-name registry.example.com/chem/django-prod --image-tag 0.6.0-django.1
```

Run the produced image (example):

```bash
docker run --rm -p 8001:8000 chembience/core-django-prod-app:0.6.0-django.1 \
  python -m gunicorn src.wsgi:application --bind 0.0.0.0:8000 --workers 8
```

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.
