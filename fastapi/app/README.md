# Chembience FastAPI Application

This is the async REST API service for your Chembience project. It is built using FastAPI and integrated with RDKit for chemical informatics.

## Important Files

- `.env`: Per-app runtime configuration and secrets. It is created during initialization; do not commit it. `APP_NAME` is set when the app is created (for example, `./install fastapi my-project`) and identifies the app images: `chembience/<app_name>:<tag>` and `chembience/<app_name>-prod:<tag>`.
- `docker-compose.yml`: Defines the FastAPI and PostgreSQL services; `docker-compose.override.yml` is available for local overrides.
- `src/main.py`: FastAPI application entry point and router registration.
- `src/db/schema.py`: SQLAlchemy metadata and database schema definitions.
- `src/alembic.ini`, `src/alembic/`: Alembic configuration, migration environment, and committed schema revisions.
- `src/tests/`: API and RDKit integration tests; `pytest.ini` configures pytest.
- `requirements.txt`: Add Python dependencies for this FastAPI app.
- `Dockerfile`: Development image extension that installs `requirements.txt`; `Dockerfile.prod` bakes `src/` into the production image.
- `PROD/compose.yaml`: Self-hosted production stack, including the bundled RDKit PostgreSQL image.
- `PROD/compose.external.yaml`: Production deployment for an external RDKit-enabled PostgreSQL database.
- `fastapi-init`: Starts the service if needed and applies migrations.
- `fastapi-makemigrations`, `fastapi-migrate`: Generate/review and apply Alembic migrations.
- `fastapi-configure`, `fastapi-prepare-prod`: Safely apply configuration changes or create a production image and `PROD/.env`.
- `PROD/psql`, `PROD/db-backup`, `PROD/db-restore`, `PROD/db-cleanup`: Self-contained database tools for the prepared self-hosted production bundle.
- `db-backup`, `db-restore`, `db-cleanup`, `psql`: Database maintenance and access helpers.

## Getting Started

To start the FastAPI service along with the PostgreSQL database:

```bash
docker compose up -d
```

For initial setup:

```bash
./fastapi-init
```

The API is then available at `http://localhost:${FASTAPI_CONNECTION_PORT}`
(default `8002`), with interactive documentation at `/docs`.

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

The database has no host port by default. Services connect to
`postgres:5432`; use `./psql` or a local Compose override for host access.

For platform documentation, see the [Chembience core README](https://github.com/chembience/core#readme).

## Configuration

- Use `./fastapi-configure [--rebuild] [NEW_ENV_FILE]` to manage development environment updates safely.
- Use `./fastapi-configure --prod` to create or deliberately refresh `.env.prod` from `.env` before editing production settings.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image that does not depend on bind mounts.

`fastapi-prepare-prod` pulls the matching published core image
`chembience/core-fastapi:${CHEMBIENCE_VERSION}` before building the source-baked
application image. No local core-image build is required.

```bash
./fastapi-prepare-prod
```

Prepare the self-hosted production bundle from the development workspace:

```bash
./fastapi-prepare-prod
cd PROD
docker compose up -d
```

It uses the Compose project name `<app_name>-prod`, initializes the named
PostgreSQL volume, applies Alembic migrations, then stops the prepared stage.
`docker compose up -d` from `PROD/` starts it later.

What the script does:
- Copies `./.env.prod` to `PROD/.env` when it exists; otherwise copies `./.env`, then forces `CHEMBIENCE_RUNTIME_MODE=prod`.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Initializes self-hosted PostgreSQL and applies Alembic migrations, then stops the stack without removing its volume.
- Uses the production image name: `chembience/<app_name>-prod:<tag>`.
- Verifies the image contains `/home/app/src/main.py`.
- Does **not** run `fastapi-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `PROD/.env`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

To maintain separate production settings, run `./fastapi-configure --prod`, edit
the generated `.env.prod`, then run `./fastapi-prepare-prod`. `.env.prod` is
copied on each preparation run unless `--keep-env-prod` is supplied.

Examples:

```bash
# Repeatable release image build
./fastapi-prepare-prod --image-tag 0.6.1-fastapi.1

# Custom production image repository/name
./fastapi-prepare-prod --image-name registry.example.com/chem/fastapi-prod --image-tag 0.6.1-fastapi.1
```

Run the produced image (example):

```bash
docker run --rm -p 8002:8000 chembience/app-prod:0.6.1-fastapi.1 \
  sh -c "alembic upgrade head && exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2"
```

For orchestrated deployments, run `alembic upgrade head` as a one-shot release
step before starting or replacing API workers, rather than once per replica.

## Production deployment

`fastapi-prepare-prod` writes the immutable application image reference and the
matching `CHEMBIENCE_POSTGRES_IMAGE` to `PROD/.env`. Deploy with one of the
following profiles.

### External database

Set `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_NAME` in `PROD/.env` for a reachable PostgreSQL database that already
has the RDKit extension installed. Apply migrations before starting workers:

```bash
cd PROD
docker compose -f compose.external.yaml run --rm migrate
docker compose -f compose.external.yaml up -d fastapi
```

### Self-hosted RDKit PostgreSQL

Leave `POSTGRES_HOST=postgres` in `PROD/.env`. `compose.yaml` starts the bundled
RDKit PostgreSQL image with a named `postgres-data` volume and keeps its port
private to the Compose network:

```bash
cd PROD
docker compose up -d postgres
docker compose up -d
```

For an external database, backups, TLS, and network access are managed by its
operator. The application currently uses the supplied PostgreSQL connection
settings without adding TLS-specific options.

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.

## Kubernetes deployment

Chembience's Helm chart is the Kubernetes alternative to this application's
self-hosted `PROD/` Compose bundle. After `fastapi-prepare-prod`, the complete
chart and deployment documentation live in `PROD/k8s/`; no core checkout
is required. Publish the immutable image, create a Kubernetes Secret outside
Helm, and deploy from that directory:

```bash
kubectl -n chembience create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me'

cd PROD/k8s
cp values.override.yaml.example values.override.yaml
helm upgrade --install myapi ./chart -n chembience \
  -f values.generated.yaml -f values.override.yaml
```

For schema changes, run the release with `--set migration.enabled=true --wait`.
The chart runs Alembic as a pre-upgrade hook before API pods use the new image;
follow with the normal chart upgrade with migrations disabled. Enable optional
Ingress only after selecting its controller and TLS configuration. The runtime
mode remains `prod`; use `chembience` for the namespace/environment name.
