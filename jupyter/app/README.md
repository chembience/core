# Chembience JupyterLab Service

This service provides a JupyterLab environment integrated with RDKit and pre-configured to connect to the Chembience PostgreSQL database.

## Features

- **JupyterLab**: Modern web-based interface for notebooks.
- **RDKit**: Chemical informatics and machine learning software.
- **SQLAlchemy & [Razi](https://github.com/rvianello/razi)**: Database toolkit and RDKit-Postgres integration for chemical data queries.
- **Pre-configured Connectivity**: Automatically connects to the `postgres` service using environment variables.

## Getting Started

To start the JupyterLab service along with the PostgreSQL database:

```bash
docker compose up -d
```

Then verify the environment and print the access URL:

```bash
./jupyter-init
```

Open the printed URL in your browser. The default port is 8888 and can be
changed via `JUPYTER_CONNECTION_PORT` in your `.env` file. On first start, the
entrypoint generates and persists a strong `JUPYTER_TOKEN` unless you supplied
one yourself.

## Important Files

- `.env`: Per-app runtime configuration and secrets, including an optional `JUPYTER_TOKEN`. It is created during initialization; do not commit it. `APP_NAME` is set by the build target and identifies the app images: `chembience/<app_name>:<tag>` and `chembience/<app_name>-prod:<tag>`.
- `docker-compose.yml`: Defines the JupyterLab and PostgreSQL services for this app.
- `notebooks/`: Your notebooks and supporting Python files. `notebooks/check_env.py` verifies RDKit and database connectivity.
- `app-requirements.txt`: Add Python dependencies for notebooks and scripts. The generated app also has `requirements.txt`, which contains the core Jupyter dependencies.
- `Dockerfile`: Development image extension that installs `app-requirements.txt`; `Dockerfile.prod` bakes notebooks into the production image.
- `PROD/compose.yaml`: Self-hosted production stack, including the bundled RDKit PostgreSQL image.
- `PROD/compose.external.yaml`: Production deployment for an external RDKit-enabled PostgreSQL database.
- `jupyter-init`: Starts JupyterLab if necessary, validates the environment, and prints the access URL/token.
- `jupyter-configure`: Safely applies `.env` updates and refreshes the service.
- `jupyter-prepare-prod`: Builds the production image and writes `PROD/.env`.
- `PROD/psql`, `PROD/db-backup`, `PROD/db-restore`, `PROD/db-cleanup`: Self-contained database tools for the prepared self-hosted production bundle.
- `psql`: Opens a PostgreSQL client connected to this app's database.

## Verifying the Environment

You can verify that everything is correctly set up by running the `check_env.py` script from within JupyterLab terminal or as a notebook cell:

```python
%run notebooks/check_env.py
```

Or via docker exec:

```bash
docker compose exec jupyter python notebooks/check_env.py
```

## Database Access

The environment is pre-configured with the following variables for database access (matching the `postgres` service):
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_NAME`
- `POSTGRES_HOST`
- `POSTGRES_PORT` (Internal port 5432)

Postgres is not published to the host by default. Use `./psql` for an
interactive database shell or add a local Compose override if host access is
needed.

## Configuration

- Use `./jupyter-configure [--rebuild] [NEW_ENV_FILE]` to manage development environment updates safely.
- Use `./jupyter-configure --prod` to create or deliberately refresh `.env.prod` from `.env` before editing production settings.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes and refresh the service.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image that includes your notebooks and app dependencies.

Prepare the self-hosted production bundle from the development workspace:

```bash
./jupyter-prepare-prod
cd PROD
docker compose up -d
```

It uses the Compose project name `<app_name>-prod`, initializes the named
PostgreSQL volume, then stops the prepared stage. `docker compose up -d` from
`PROD/` starts it later.

`jupyter-prepare-prod` pulls the matching published core image
`chembience/core-jupyter:${CHEMBIENCE_VERSION}` before building the source-baked
application image. No local core-image build is required.

```bash
./jupyter-prepare-prod
```

What the script does:
- Copies `./.env.prod` to `PROD/.env` when it exists; otherwise copies `./.env`, then forces `CHEMBIENCE_RUNTIME_MODE=prod`.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Initializes self-hosted PostgreSQL, then stops the stack without removing its volume.
- Uses the production image name: `chembience/<app_name>-prod:<tag>`.
- Verifies the image contains `/home/app/notebooks`.
- Does **not** run `jupyter-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `PROD/.env`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

To maintain separate production settings, run `./jupyter-configure --prod`, edit
the generated `.env.prod`, then run `./jupyter-prepare-prod`. `.env.prod` is
copied on each preparation run unless `--keep-env-prod` is supplied.

Examples:

```bash
# Repeatable release image build
./jupyter-prepare-prod --image-tag 0.6.1-jupyter.1

# Custom production image repository/name
./jupyter-prepare-prod --image-name registry.example.com/chem/jupyter-prod --image-tag 0.6.1-jupyter.1
```

Run the produced image (example):

```bash
docker run --rm -p 8888:8888 chembience/app-prod:0.6.1-jupyter.1 \
  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
```

## Production deployment

`jupyter-prepare-prod` writes the immutable application image reference and the
matching `CHEMBIENCE_POSTGRES_IMAGE` to `PROD/.env`. For an external database,
set `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_NAME` in `PROD/.env`; that database must already have the RDKit
extension installed:

```bash
cd PROD
docker compose -f compose.external.yaml up -d jupyter
```

For a self-hosted database, leave `POSTGRES_HOST=postgres`; the overlay creates
a private RDKit PostgreSQL service with a named `postgres-data` volume:

```bash
cd PROD
docker compose up -d
```

For an external database, backups, TLS, and network access are managed by its
operator. The application currently uses the supplied PostgreSQL connection
settings without adding TLS-specific options.

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.

### Token behavior

- Token auth is enabled by default. The generated app pins a token in `.env`
  on first start (unless `JUPYTER_TOKEN` was already set), and
  `./jupyter-init` prints the corresponding URL.
- To disable the token in development, use the provided overlay:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
  ```
- To choose a stable token, set `JUPYTER_TOKEN` in `.env`; no compose override
  is needed.

## Kubernetes deployment

Chembience's Helm chart is the Kubernetes alternative to this application's
self-hosted `PROD/` Compose bundle. After `jupyter-prepare-prod`, the complete
chart and deployment documentation live in `PROD/kubernetes/`; no core checkout
is required. Publish the immutable image, then create its credentials outside
Helm and deploy from that directory:

```bash
kubectl -n production create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me' \
  --from-literal=jupyter-token='replace-me'

cd PROD/kubernetes
cp values.override.yaml.example values.override.yaml
helm upgrade --install notebooks ./chart -n production \
  -f values.generated.yaml -f values.override.yaml
```

Enable optional Ingress only with a chosen controller and TLS configuration;
keep the Jupyter token enabled in production. The chart uses immutable runtime
mode `prod`, while `production` is the namespace/environment name.
