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

Then print the access URL (with token when available):

```bash
./jupyter-init
```

Open the printed URL in your browser. The default port is 8888 and can be
changed via `JUPYTER_CONNECTION_PORT` in your `.env` file.

## Directory Structure

- `notebooks/`: Default directory for your Jupyter notebooks.
  - `check_env.py`: A script to verify that RDKit and the database connection are working correctly.
- `psql`: Helper script for accessing the PostgreSQL database directly.
- `jupyter-init`: Script to verify the environment and start the service if needed.
- `requirements.txt`: Python dependencies installed in this environment.

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

## Configuration

- Use `./jupyter-configure [--rebuild] [NEW_ENV_FILE]` to manage environment updates safely.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes and refresh the service.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image that includes your notebooks and app dependencies.

Prerequisite:
- The base core image must exist locally: `chembience/core-jupyter:${CHEMBIENCE_VERSION}` from your app `.env` (for example, run `./build` from repository root first).

```bash
./jupyter-prepare-prod
```

What the script does:
- Creates/reuses `./.env.prod` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Uses a clear production image name: `chembience/core-jupyter-prod-<app_name>:<tag>`.
- Verifies the image contains `/home/app/notebooks`.
- Does **not** run `jupyter-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `./.env.prod`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

Examples:

```bash
# Repeatable release image build
./jupyter-prepare-prod --image-tag 0.6.0-jupyter.1

# Custom production image repository/name
./jupyter-prepare-prod --image-name registry.example.com/chem/jupyter-prod --image-tag 0.6.0-jupyter.1
```

Run the produced image (example):

```bash
docker run --rm -p 8888:8888 chembience/core-jupyter-prod-app:0.6.0-jupyter.1 \
  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
```

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.

### Token behavior

- Token auth is enabled by default. If Jupyter auto-generates a token,
  `./jupyter-init` will query the server and print a URL like
  `http://localhost:8888/?token=<...>`.
- To disable the token in development, use the provided overlay:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
  ```
- To pin a stable token, set `JUPYTER_TOKEN` in `.env` and pass it via a small
  compose override that appends `--ServerApp.token=${JUPYTER_TOKEN}` to the
  `jupyter` service command.
