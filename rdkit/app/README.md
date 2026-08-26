# Chembience RDKit Application

This is the RDKit service for your Chembience project. It provides specialized chemical processing capabilities.

## Important Files

- `.env`: Per-app runtime configuration and secrets. It is created during initialization; do not commit it. `APP_NAME` is set when the app is created (for example, `./install rdkit my-project`) and identifies the app images: `chembience/<app_name>:<tag>` and `chembience/<app_name>-prod:<tag>`.
- `docker-compose.yml`: Defines the RDKit sidecar and PostgreSQL services for this app.
- `requirements.txt`: Add Python dependencies for RDKit scripts.
- `Dockerfile`: Development image extension that installs `requirements.txt`; `Dockerfile.prod` creates a source-baked production image.
- `PROD/compose.yaml`: Self-hosted production stack, including the bundled RDKit PostgreSQL image.
- `PROD/compose.external.yaml`: Production deployment for an external RDKit-enabled PostgreSQL database.
- `run`: Runs a Python script inside the RDKit container: `./run your_script.py`.
- `shell`: Opens an interactive Python shell in the RDKit container.
- `rdkit-init`: Starts the RDKit service if necessary and verifies the installed RDKit version.
- `rdkit-configure`: Safely applies `.env` updates and refreshes the environment.
- `rdkit-prepare-prod`: Builds the production image and writes `PROD/.env`.
- `rdkit-prod-self-hosted`: Compatibility shortcut that prepares the production bundle and starts it.
- `PROD/psql`, `PROD/db-backup`, `PROD/db-restore`, `PROD/db-cleanup`: Self-contained database tools for the prepared self-hosted production bundle.
- `psql`: Opens a PostgreSQL client connected to this app's database.

## Getting Started

To start the stack along with the PostgreSQL database:

```bash
docker compose up -d
```

Verify the environment after the first start:

```bash
./rdkit-init
```

To run a script in the RDKit environment:
```bash
./run your_script.py
```

To access the interactive shell:
```bash
./shell
```

For platform documentation, see the [Chembience core README](https://github.com/chembience/core#readme).

The long-running `rdkit` service is intended for scripts and ad-hoc Python
sessions. It connects to the private database at `postgres:5432`; use `./psql`
or add a local Compose override if host access is needed.

## Configuration

- Use `./rdkit-configure [--rebuild] [NEW_ENV_FILE]` to manage environment updates safely.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes and refresh the environment.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image for RDKit scripts and runtime tooling.

`rdkit-prepare-prod` pulls the matching published core image
`chembience/core-rdkit:${CHEMBIENCE_VERSION}` before building the source-baked
application image. No local core-image build is required.

```bash
./rdkit-prepare-prod
```

Prepare the self-hosted production bundle from the development workspace:

```bash
./rdkit-prepare-prod
cd PROD
docker compose up -d
```

It uses the Compose project name `<app_name>-prod`, initializes the named
PostgreSQL volume, then stops the prepared stage. `docker compose up -d` from
`PROD/` starts it later.

What the script does:
- Creates/reuses `PROD/.env` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Initializes self-hosted PostgreSQL, then stops the stack without removing its volume.
- Uses the production image name: `chembience/<app_name>-prod:<tag>`.
- Runs an RDKit smoke check from the built image (`MolFromSmiles`).
- Does **not** run `rdkit-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `PROD/.env`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

Examples:

```bash
# Repeatable release image build
./rdkit-prepare-prod --image-tag 0.6.1-rdkit.1

# Custom production image repository/name
./rdkit-prepare-prod --image-name registry.example.com/chem/rdkit-prod --image-tag 0.6.1-rdkit.1
```

Run the produced image (example):

```bash
docker run --rm --entrypoint /opt/conda/envs/chembience/bin/python chembience/app-prod:0.6.1-rdkit.1 - <<'PY'
from rdkit import Chem
print(bool(Chem.MolFromSmiles('CCO')))
PY
```

## Production deployment

`rdkit-prepare-prod` writes the immutable application image reference and the
matching `CHEMBIENCE_POSTGRES_IMAGE` to `PROD/.env`. For an external database,
set `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`POSTGRES_NAME` in `PROD/.env`; that database must already have the RDKit
extension installed:

```bash
cd PROD
docker compose -f compose.external.yaml up -d rdkit
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
