# Chembience Django Application

This is the web service for your Chembience project. It is built using Django and integrated with RDKit for chemical informatics.

## Important Files

- `.env`: Per-app runtime configuration and secrets. It is created during initialization; do not commit it. `APP_NAME` is set when the app is created (for example, `./install django my-project`) and identifies the app images: `chembience/<app_name>:<tag>` and `chembience/<app_name>-prod:<tag>`.
- `docker-compose.yml`: Defines the Django and PostgreSQL services for this app.
- `src/`: Django project source. `manage.py` is the entry point; edit application code, settings, URLs, and migrations here.
- `requirements.txt`: Add Python dependencies for this Django app.
- `Dockerfile`: Development image extension that installs `requirements.txt`.
- `Dockerfile.prod`: Production image recipe that bakes `src/` into an immutable image.
- `PROD/compose.yaml`: Self-hosted production stack, including the bundled RDKit PostgreSQL image.
- `PROD/compose.external.yaml`: Production deployment for an external RDKit-enabled PostgreSQL database.
- `django-init`: Runs migrations, creates the configured superuser, collects static files, and runs the test suite.
- `django-manage-py`: Runs any `manage.py` command as the container's application user.
- `django-configure`: Safely applies `.env` updates, including database-password rotation.
- `django-prepare-prod`: Builds the production image and writes `PROD/.env`.
- `PROD/psql`, `PROD/db-backup`, `PROD/db-restore`, `PROD/db-cleanup`: Self-contained database tools for the prepared self-hosted production bundle.
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

- Use `./django-configure [--rebuild] [NEW_ENV_FILE]` to manage development environment updates safely.
- Use `./django-configure --prod` to create or deliberately refresh `.env.prod` from `.env` before editing production settings.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes (handles password rotation, migrations, superuser check).
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image that includes your Django project source.

`django-prepare-prod` pulls the matching published core image
`chembience/core-django:${CHEMBIENCE_VERSION}` before building the source-baked
application image. No local core-image build is required.

```bash
./django-prepare-prod
```

Prepare the self-hosted production bundle from the development workspace:

```bash
./django-prepare-prod
cd PROD
docker compose up -d
```

It uses the Compose project name `<app_name>-prod`, initializes the named
PostgreSQL volume, applies Django migrations, then stops the prepared stage.
`docker compose up -d` from `PROD/` starts it later.

What the script does:
- Copies `./.env.prod` to `PROD/.env` when it exists; otherwise copies `./.env`, then forces `CHEMBIENCE_RUNTIME_MODE=prod`.
- Seeds `DJANGO_CSRF_TRUSTED_ORIGINS` with direct HTTP origins derived from the production port and `DJANGO_VIRTUAL_HOSTNAME`.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Initializes self-hosted PostgreSQL and applies Django migrations, then stops the stack without removing its volume.
- Uses the production image name: `chembience/<app_name>-prod:<tag>`.
- Verifies the image contains `/home/app/src/manage.py`.
- Does **not** run `django-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `PROD/.env`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

To maintain separate production settings, run `./django-configure --prod`, edit
the generated `.env.prod`, then run `./django-prepare-prod`. `.env.prod` is
copied on each preparation run unless `--keep-env-prod` is supplied.

For a strictly Kubernetes-based deployment, use
`./django-prepare-prod --target ghcr-k8s`. This does not run Docker locally: on
its first use it creates the GitHub Actions configuration that publishes a
private image to GHCR. Commit and push that configuration, wait for the Action,
then rerun the command from the clean pushed commit to generate the SHA-pinned
Helm values file. See [PROD/k8s/README.md](PROD/k8s/README.md) for the complete
workflow.

Examples:

```bash
# Repeatable release image build
./django-prepare-prod --image-tag 0.6.2-pre1-django.1

# Custom production image repository/name
./django-prepare-prod --image-name registry.example.com/chem/django-prod --image-tag 0.6.2-pre1-django.1
```

Run the produced image (example):

```bash
docker run --rm -p 8001:8000 chembience/app-prod:0.6.2-pre1-django.1 \
  python -m gunicorn src.wsgi:application --bind 0.0.0.0:8000 --workers 8
```

## Production deployment

`django-prepare-prod` writes the immutable application image reference and the
matching `CHEMBIENCE_POSTGRES_IMAGE` to `PROD/.env`. Deploy with one of the
following profiles.

### Production administrator

Before preparation, set non-placeholder `DJANGO_SUPERUSER_USERNAME`,
`DJANGO_SUPERUSER_EMAIL`, and `DJANGO_SUPERUSER_PASSWORD` in the app `.env`.
For the self-hosted database, `django-prepare-prod` runs migrations and then
creates or updates that administrator in the separate production database. It
fails rather than prepare a bundle with a missing or placeholder administrator
password. Rerun `./django-prepare-prod` after changing the password to apply
the new value to an existing `PROD` database.

### Public URL and CSRF

`DJANGO_VIRTUAL_HOSTNAME` controls Django's allowed hostnames. CSRF protection
uses the separate `DJANGO_CSRF_TRUSTED_ORIGINS` setting, whose entries must be
full browser origins (scheme and port included). `django-prepare-prod` seeds
local HTTP defaults such as `http://localhost:9001`. Before deploying through a
public URL, replace them in `PROD/.env`, for example:

```env
DJANGO_VIRTUAL_HOSTNAME=chem.example.org
DJANGO_CSRF_TRUSTED_ORIGINS=https://chem.example.org
```

The PROD Compose files load these values through Chembience's production
settings overlay, so this also applies when the application was created with an
older core image.

When TLS terminates at a trusted reverse proxy, set
`DJANGO_TRUST_X_FORWARDED_PROTO=True` only if that proxy supplies and sanitizes
the `X-Forwarded-Proto` header. This allows Django to recognize the original
HTTPS request.

### External database

Set `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_NAME` in `PROD/.env` for a reachable PostgreSQL database that already
has the RDKit extension installed. Apply migrations before starting workers:

```bash
cd PROD
docker compose -f compose.external.yaml run --rm migrate
docker compose -f compose.external.yaml up -d django
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

Read [PROD/README.md](PROD/README.md) when preparing or operating this Django
application with self-hosted Docker Compose.

## Kubernetes deployment

Chembience's Helm chart is the Kubernetes alternative to this application's
self-hosted `PROD/` Compose bundle. Prepare it with
`django-prepare-prod --target ghcr-k8s`; the generated `PROD/k8s/` directory is
self-contained and can be copied to a Kubernetes-only host. Create the
namespace and Secrets before Helm, adapt `values.override.yaml`, then deploy
the SHA-pinned values with Helm. The app-specific Kubernetes README gives the
complete ordered commands.

Enable the chart's optional Ingress only after selecting an Ingress controller
and TLS strategy. The chart sets `CHEMBIENCE_RUNTIME_MODE=prod`; `chembience`
is the namespace/environment name. For releases with migrations, enable the
migration Job during the Helm upgrade and use `--wait`; its pre-upgrade hook
completes before new Django workers are rolled out.

Read [PROD/k8s/README.md](PROD/k8s/README.md) when deploying this Django
application to Kubernetes, especially for GHCR, Secrets, and migrations.
