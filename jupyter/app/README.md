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

## Dev-to-Prod Promotion

Use this workflow when your project is ready to run with `CHEMBIENCE_RUNTIME_MODE=prod`.

1. Keep developing in `dev` mode.
2. Run:

```bash
./jupyter-prepare-prod
```

What the script does:
- Creates `./.env.prod` from your current `./.env`.
- Sets `CHEMBIENCE_RUNTIME_MODE=prod` in `./.env.prod`.
- Applies it through `./jupyter-configure ./.env.prod`.
- Runs `docker compose config` and prints token guidance.

Optional flags:
- `--rebuild` → passes through to `jupyter-configure --rebuild`.
- `--keep-env-prod` → reuses existing `./.env.prod`.

Recommended post-promotion checks:

```bash
docker compose --env-file ./.env ps
./jupyter-init
docker compose --env-file ./.env exec -T jupyter python notebooks/check_env.py
```

Current Phase 2 caveats:
- In `prod`, Jupyter skips most helper file sync and `.env` mutation.
- Ensure your notebooks/config are already present and your token strategy is explicit (`JUPYTER_TOKEN` set or intentionally empty for disabled auth).

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
