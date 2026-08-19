# Chembience RDKit Application

This is the RDKit service for your Chembience project. It provides specialized chemical processing capabilities.

## Important Files

- `.env`: Per-app runtime configuration and secrets. It is created during initialization; do not commit it. `APP_NAME` is set when the app is created (for example, `./build rdkit my-project`) and should normally remain unchanged because it identifies this app's container-image and production-image names.
- `docker-compose.yml`: Defines the RDKit sidecar and PostgreSQL services for this app.
- `requirements.txt`: Add Python dependencies for RDKit scripts.
- `Dockerfile`: Development image extension that installs `requirements.txt`; `Dockerfile.prod` creates a source-baked production image.
- `docker-compose.prod.yml`: Production deployment for an external RDKit-enabled PostgreSQL database.
- `docker-compose.prod.self-hosted.yml`: Overlay that runs the bundled RDKit PostgreSQL image with a named persistent volume.
- `run`: Runs a Python script inside the RDKit container: `./run your_script.py`.
- `shell`: Opens an interactive Python shell in the RDKit container.
- `rdkit-init`: Starts the RDKit service if necessary and verifies the installed RDKit version.
- `rdkit-configure`: Safely applies `.env` updates and refreshes the environment.
- `rdkit-prepare-prod`: Builds the production image and writes `.env.prod`.
- `rdkit-prod-self-hosted`: Builds (or refreshes) the production image and starts the isolated self-hosted production stack.
- `psql`: Opens a PostgreSQL client connected to this app's database.

## Getting Started

To start the stack along with the PostgreSQL database:

```bash
docker compose up -d
```

To run a script in the RDKit environment:
```bash
./run your_script.py
```

To access the interactive shell:
```bash
./shell
```

For more information, see the root [README.md](../../README.md).

## Configuration

- Use `./rdkit-configure [--rebuild] [NEW_ENV_FILE]` to manage environment updates safely.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes and refresh the environment.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image for RDKit scripts and runtime tooling.

Prerequisite:
- The base core image must exist locally: `chembience/core-rdkit:${CHEMBIENCE_VERSION}` from your app `.env` (for example, run `./build` from repository root first).

```bash
./rdkit-prepare-prod
```

For the complete self-hosted deployment, use:

```bash
./rdkit-prod-self-hosted
```

It uses the Compose project name `<app_name>-prod`. Use `--skip-prepare` to
start an already prepared image without rebuilding it.

What the script does:
- Creates/reuses `./.env.prod` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Uses a clear production image name: `chembience/core-rdkit-prod-<app_name>:<tag>`.
- Runs an RDKit smoke check from the built image (`MolFromSmiles`).
- Does **not** run `rdkit-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `./.env.prod`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

Examples:

```bash
# Repeatable release image build
./rdkit-prepare-prod --image-tag 0.6.0-rdkit.1

# Custom production image repository/name
./rdkit-prepare-prod --image-name registry.example.com/chem/rdkit-prod --image-tag 0.6.0-rdkit.1
```

Run the produced image (example):

```bash
docker run --rm --entrypoint /opt/conda/envs/chembience/bin/python chembience/core-rdkit-prod-app:0.6.0-rdkit.1 - <<'PY'
from rdkit import Chem
print(bool(Chem.MolFromSmiles('CCO')))
PY
```

## Production deployment

`rdkit-prepare-prod` writes the immutable application image reference and the
matching `CHEMBIENCE_POSTGRES_IMAGE` to `.env.prod`. For an external database,
set `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_NAME` in `.env.prod`; that database must already have the RDKit
extension installed:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d rdkit
```

For a self-hosted database, leave `POSTGRES_HOST=postgres`; the overlay creates
a private RDKit PostgreSQL service with a named `postgres-data` volume:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml -f docker-compose.prod.self-hosted.yml up -d
```

For an external database, backups, TLS, and network access are managed by its
operator. The application currently uses the supplied PostgreSQL connection
settings without adding TLS-specific options.

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.
