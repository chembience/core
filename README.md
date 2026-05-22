# Chembience

Chembience is a specialized platform for chemical informatics, using Django for the web interface and API, and RDKit for chemical data processing.

## Prerequisites

- **Docker**: Version 20.10.0 or higher
- **Docker Compose**: Version 2.0.0 or higher
- **Bash**: (Linux/macOS/WSL2)

## Major Software Libraries

- **Python**: 3.14
- **RDKit**: 2026.03.2
- **PostgreSQL**: 18 (PostGIS/rdkit-ready)
- **Django**: 5.x
- **SQLAlchemy**: latest
- **FastAPI**: latest
- **JupyterLab**: latest
- **django-rdkit**: [latest](https://github.com/rdkit/django-rdkit) (GitHub)
- **razi**: [latest](https://github.com/rvianello/razi) (GitHub)


## Installation & Setup

1.  **Clone the repository.**
2.  **Navigate to the `core/` directory:**
    ```bash
    cd core
    ```
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
    or
    ```bash
    ./build fastapi myapp
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
  `DJANGO_SECRET_KEY` in `core/.env` *before* running `./build`; it will be
  forwarded to the container and persisted into the project `.env`.
- Rotating the key (replacing it in the project `.env` and restarting) will
  log out all existing users and invalidate any outstanding signed tokens.
- The key is never baked into the Docker image; generation happens at
  container start, inside the bind-mounted volume.

## Services

Chembience ships five services, all wired together via `core/docker-compose.yml`:

| Service   | Path             | Purpose                                                 |
| --------- | ---------------- | ------------------------------------------------------- |
| `django`  | `core/django`    | Main Django web app (`src/`).                       |
| `fastapi` | `core/fastapi`   | Async REST API (`src/`).                            |
| `jupyter` | `core/jupyter`   | JupyterLab environment with RDKit + Postgres pre-wired. |
| `rdkit`   | `core/rdkit`     | RDKit shell / base image for one-shot scripts.          |
| `postgres`| `core/postgres`  | PostgreSQL with the RDKit cartridge.                    |

Note on naming: Both Django and FastAPI use `src/` for their application
source code within the container. This provides a consistent naming convention
across the platform.

## Helper Scripts

Thin Bash wrappers around `docker compose` and the per-service entrypoints.
All are intended to be run from `core/` unless noted.

- `./build <type> <target> [-d <parent_dir>]` — bootstrap a new project.
- `./remove <target> [-d <parent_dir>]` — tear it down.
- `./psql` — open a `psql` shell on the Postgres container.
- `core/django/django-init`, `core/django/django-manage-py`,
  `core/django/psql` — Django-side helpers
  (project init, `manage.py` proxy, DB shell).
- `core/fastapi/app/fastapi-init`, `core/fastapi/app/db_backup`,
  `core/fastapi/app/db_cleanup`, `core/fastapi/app/db_restore` —
  FastAPI-side helpers.
- `core/jupyter/app/jupyter-init` — Jupyter project bootstrap.
- `core/rdkit/app/run`, `core/rdkit/app/shell` — RDKit one-shot run / shell.

## Common Commands

Running from the `core/` directory:

- **Remove an application**:
  ```bash
  ./remove <target>
  ```
  If you used a custom directory:
  ```bash
  ./remove <target> -d /path/to/parent_dir
  ```

## Development

For more detailed information, see:
- [CLAUDE.md](https://github.com/chembience/chembience/blob/main/core/CLAUDE.md): Development guide and common commands.
- [AGENTS.md](https://github.com/chembience/chembience/blob/main/core/AGENTS.md): Information for AI agents and high-level overview.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](https://github.com/chembience/chembience/blob/main/core/LICENSE) file for details.
