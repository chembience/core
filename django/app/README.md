# Chembience Django Application

This is the web service for your Chembience project. It is built using Django and integrated with RDKit for chemical informatics.

## Important Files

- `.env`: Per-app runtime configuration and secrets. It is created during initialization; do not commit it. `APP_NAME` is set when the app is created (for example, `./build django my-project`) and identifies the app images: `chembience/<app_name>:<tag>` and `chembience/<app_name>-prod:<tag>`.
- `docker-compose.yml`: Defines the Django and PostgreSQL services for this app.
- `src/`: Django project source. `manage.py` is the entry point; edit application code, settings, URLs, and migrations here.
- `requirements.txt`: Add Python dependencies for this Django app.
- `Dockerfile`: Development image extension that installs `requirements.txt`.
- `Dockerfile.prod`: Production image recipe that bakes `src/` into an immutable image.
- `docker-compose.prod.yml`: Production deployment for an external RDKit-enabled PostgreSQL database.
- `docker-compose.prod.self-hosted.yml`: Overlay that runs the bundled RDKit PostgreSQL image with a named persistent volume.
- `django-init`: Runs migrations, creates the configured superuser, collects static files, and runs the test suite.
- `django-manage-py`: Runs any `manage.py` command as the container's application user.
- `django-configure`: Safely applies `.env` updates, including database-password rotation.
- `django-prepare-prod`: Builds the production image and writes `.env.prod`.
- `django-prod-self-hosted`: Builds (or refreshes) the production image, applies migrations, and starts the isolated self-hosted production stack.
- `psql`: Opens a PostgreSQL client connected to this app's database.
- `src/django_rdkit_test_app/`: Retained RDKit integration smoke-test app and its tests.

## Getting Started

To start the Django service along with the PostgreSQL database:

```bash
docker compose up -d
```


For initial setup and a smoke test:

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

After changing models, generate, review, and commit the migration files under
`src/` before applying them:

```bash
./django-manage-py makemigrations
./django-manage-py migrate
```

To access the database:
```bash
./psql
```

For platform documentation, see the [Chembience core README](https://github.com/chembience/core#readme).

The database is intentionally private to the Compose network. Application
containers reach it as `postgres:5432`; use `./psql` or add a local Compose
override if host access is required.

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

For the complete self-hosted deployment, use:

```bash
./django-prod-self-hosted
```

It uses the Compose project name `<app_name>-prod`, applies Django migrations
before starting the web service, and assigns a newly created `.env.prod` the
development port plus 1000 (normally `9001`). Use `--skip-prepare` to start an
already prepared image without rebuilding it.

What the script does:
- Creates/reuses `./.env.prod` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Uses the production image name: `chembience/<app_name>-prod:<tag>`.
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
docker run --rm -p 8001:8000 chembience/app-prod:0.6.0-django.1 \
  python -m gunicorn src.wsgi:application --bind 0.0.0.0:8000 --workers 8
```

## Production deployment

`django-prepare-prod` writes the immutable application image reference and the
matching `CHEMBIENCE_POSTGRES_IMAGE` to `.env.prod`. Deploy with one of the
following profiles.

### External database

Set `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_NAME` in `.env.prod` for a reachable PostgreSQL database that already
has the RDKit extension installed. Apply migrations before starting workers:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm migrate
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d django
```

### Self-hosted RDKit PostgreSQL

Leave `POSTGRES_HOST=postgres` in `.env.prod`. The overlay starts the bundled
RDKit PostgreSQL image with a named `postgres-data` volume and keeps its port
private to the Compose network:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml -f docker-compose.prod.self-hosted.yml up -d postgres
docker compose --env-file .env.prod -f docker-compose.prod.yml -f docker-compose.prod.self-hosted.yml run --rm migrate
docker compose --env-file .env.prod -f docker-compose.prod.yml -f docker-compose.prod.self-hosted.yml up -d django
```

For an external database, backups, TLS, and network access are managed by its
operator. The application currently uses the supplied PostgreSQL connection
settings without adding TLS-specific options.

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.
