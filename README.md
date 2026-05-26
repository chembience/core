# Chembience

Chembience is a Docker-based chemoinformatics platform with prewired RDKit and RDKit-enabled PostgreSQL components. It provides ready-to-use Django, FastAPI, JupyterLab, RDKit, and PostgreSQL services for building chemical informatics applications.

## What Chembience Provides

Chembience bundles a complete containerized environment for cheminformatics development:

- **RDKit** for molecular representation, descriptors, fingerprints, similarity search, and chemical data processing.
- **PostgreSQL with the RDKit cartridge** for storing, indexing, and querying chemical structures.
- **Django** for building web applications and administrative interfaces.
- **FastAPI** for building async APIs and lightweight services.
- **JupyterLab** for exploratory cheminformatics workflows.
- **Helper scripts** for bootstrapping, running, and removing generated applications.

All services are wired together with Docker Compose and share a common application directory mounted into the containers.

## Prerequisites

- **Docker**: Version 20.10.0 or higher
- **Docker Compose**: Version 2.0.0 or higher
- **Bash**: Linux, macOS, or WSL2

## Major Software Components

Versions are controlled through `.env` / `.env.example` and Docker build arguments.

- **Python**: 3.14 (configurable via `CONDA_PY`)
- **RDKit**: 2026.03.2 (configurable via `RDKIT_VERSION`)
- **PostgreSQL**: 18 (RDKit-cartridge-enabled)
- **Django**: 5.x-compatible
- **FastAPI**: 0.115+-compatible
- **SQLAlchemy**: 2.x-compatible
- **JupyterLab**: 4.x-compatible
- **django-rdkit**
- **razi**

## Installation & Setup

1.  **Clone the repository.**
2.  **Navigate to the project directory.**
3.  **Build and setup an application:**
    ```bash
    ./build <type> <target>
    ```
    - `<type>`: `django`, `fastapi`, `jupyter` or `rdkit`
    - `<target>`: Name of your application (e.g., `myapp`)

    Example:
    ```bash
    ./build django myapp
    ```

    By default, the application is created in `~/myapp`. You can specify a custom directory with the `-d` option:
    ```bash
    ./build django myapp -d /path/to/parent_dir
    ```
    This will create the app in `/path/to/parent_dir/myapp`.

## Secrets

`DJANGO_SECRET_KEY` is auto-generated on first `./build` and persisted in the
per-project `.env` inside `APP_HOME` (e.g. `~/myapp/.env`). The same key is
reused on every container restart, so sessions, signed cookies, and password
reset tokens remain valid. Treat that `.env` as a secret.

- To inject your own key (e.g. from Vault or a CI secret store), set
  `DJANGO_SECRET_KEY` in the project's `.env` *before* running `./build`; it will be
  forwarded to the container and persisted into the project `.env`.
- Rotating the key (replacing it in the project `.env` and restarting) will
  log out all existing users and invalidate any outstanding signed tokens.
- The key is never baked into the Docker image; generation happens at
  container start, inside the bind-mounted volume.

## Services Overview

Chembience ships several services, all wired together via `docker-compose.yml`:

| Service      | Directory    | Purpose                                                 |
| ------------ | ------------ | ------------------------------------------------------- |
| `django`     | `django/`    | Main Django web app.                                    |
| `fastapi`    | `fastapi/`   | Async REST API.                                         |
| `jupyter`    | `jupyter/`   | JupyterLab environment with RDKit + Postgres pre-wired. |
| `rdkit`      | `rdkit/`     | RDKit interactive one-shot Python shell.                |
| `rdkit-app`  | `rdkit/app`  | Long-running sidecar for RDKit-based scripts.           |
| `postgres`   | `postgres/`  | PostgreSQL 18 with the RDKit cartridge.                 |

## Repository Layout

- `docker-compose.yml`: Authoritative definition of all services and how they interact.
- `.env.example`: Template for environment configuration.
- `build`: Script to bootstrap a new project.
- `remove`: Script to tear down a project and optionally remove images.
- `psql`: Helper script to open a `psql` shell.
- `test-build-all`: Script to verify all application types.
- `django/`, `fastapi/`, `jupyter/`, `rdkit/`, `postgres/`: Service-specific Dockerfiles and initialization scripts.

## Helper Scripts

Thin Bash wrappers around `docker compose` and the per-service entrypoints.

- `./build <type> <target> [-d <parent_dir>]` — bootstrap a new project.
- `./remove <target> [-d <parent_dir>] [-i|--images] [--silent|-s]` — tear it down.
- `./psql` — open a `psql` shell on the Postgres container.
- `./test-build-all` — Test script to build and init all app types.

Per-service init helpers:
- `django/django-init`, `django/django-manage-py`, `django/psql`
- `fastapi/app/fastapi-init`, `fastapi/app/db_backup`, `fastapi/app/db_cleanup`, `fastapi/app/db_restore`
- `jupyter/app/jupyter-init`
- `rdkit/app/rdkit-init`, `rdkit/app/run`, `rdkit/app/shell`

## Development

For more detailed information, see:
- [CLAUDE.md](CLAUDE.md): Development guide and common commands.
- [AGENTS.md](AGENTS.md): Information for AI agents and high-level overview.
- [LICENSE](LICENSE): BSD 3-Clause License.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
