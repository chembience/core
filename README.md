# Chembience

Chembience is a Docker-based chemoinformatics platform with prewired RDKit and RDKit-enabled PostgreSQL components. 
It provides ready-to-use Django, FastAPI, JupyterLab, RDKit, and PostgreSQL services for building chemical informatics 
applications.



## What Chembience Provides

Chembience bundles a complete containerized environment for cheminformatics development:

- **RDKit** for molecular representation, descriptors, fingerprints, similarity search, and chemical data processing.
- **PostgreSQL with the RDKit cartridge** for storing, indexing, and querying chemical structures.
- **Django** for building web applications and administrative interfaces.
- **FastAPI** for building async APIs and lightweight services.
- **JupyterLab** for exploratory cheminformatics workflows.
- **Helper scripts** for bootstrapping, running, and removing generated applications.

All services are wired together with Docker Compose and share a common application directory mounted into the containers.

## Quick Start

For instance, get a JupyterLab environment with RDKit + PostgreSQL running in a few commands:

```bash
# 1. Clone the repository
git clone https://github.com/chembience/core.git chembience
cd chembience

# 2. Build a Jupyter app (creates ~/myapp by default)
./build jupyter myapp

# 3. Switch to the generated app directory and start it
cd ~/myapp
docker compose up -d

# 4. Get the Jupyter access token from the logs
docker compose logs -f jupyter
```

Then open JupyterLab in your browser at
[http://localhost:8888/](http://localhost:8888/) and paste the token shown in
the logs. Swap `jupyter` for `django`, `fastapi`, or `rdkit` in step 2 to
bootstrap a different stack.

## Prerequisites

- **Docker**: Version 20.10.0 or higher
- **Docker Compose**: Version 2.0.0 or higher
- **Bash**: Linux, macOS, or WSL2

## Major Software Components

Versions are controlled through `.env` / `.env.example` and Docker build arguments.

- **Python**: 3.14 (configurable via `CONDA_PY`)
- **[RDKit](https://github.com/rdkit/rdkit)**: 2026.03.2 (configurable via `RDKIT_VERSION`)- **PostgreSQL**: 18 (RDKit-cartridge-enabled)
- **Django**: 5.x-compatible
- **FastAPI**: 0.115+-compatible
- **SQLAlchemy**: 2.x-compatible
- **JupyterLab**: 4.x-compatible
- **[django-rdkit](https://github.com/rdkit/django-rdkit) and [razi](https://github.com/rvianello/razi)**

## Installation & Setup

1.  **Clone the repository.**
    ```bash
    ./git clone https://github.com/chembience/core.git chembience
    ```
2.  **Navigate to the project directory.**
3. ```bash
    cd chembience
    ```
3.  **Build and set up an application:**
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
  ./build rdkit|django|fastapi|jupyter myapp -d /path/to/parent_dir
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

### PostgreSQL Password

`POSTGRES_PASSWORD` must be set in the project's `.env` before running `./build`.
The `.env.example` file contains a placeholder (`CHANGE_ME_BEFORE_RUNNING`) as a reminder.

**To change the password later**, use the `<appname>-configure` script located inside
your application directory. Each app type ships its own configure script:

| App type | Script |
| -------- | ------ |
| `django`  | `django-configure` |
| `fastapi` | `fastapi-configure` |
| `jupyter` | `jupyter-configure` |
| `rdkit`   | `rdkit-configure` |

The configure script follows a safe two-phase workflow:

1. **First run** — creates a `.env.new` file (a copy of the current `.env`) and asks you to edit it:
   ```bash
   ./django-configure
   ```
2. **Edit** — open `.env.new` and update `POSTGRES_PASSWORD` to the new value.
3. **Second run** — detects the password change, rotates it live inside the running Postgres container, then adopts the new `.env`:
   ```bash
   ./django-configure
   ```

The script automatically handles the Postgres `ALTER USER` statement with the old credentials before switching to the new ones, so no manual SQL is needed.

### Django Superuser Password

`DJANGO_SUPERUSER_PASSWORD` (together with `DJANGO_SUPERUSER_USERNAME` and
`DJANGO_SUPERUSER_EMAIL`) is read from the project's `.env` and used by the
Django init flow to create the initial admin user. Treat it as a secret:
set it in `.env` before running `./build`, never commit it, and rotate it
via `python manage.py changepassword` inside the `django` container if
needed.

### JupyterLab Token

JupyterLab is launched with its **default token authentication enabled**
(no `--ServerApp.token=''` is passed in `docker-compose.yml`). On first
start, Jupyter generates a random token; retrieve it with:

```bash
docker compose logs -f jupyter
```

To pin a stable token, set `JUPYTER_TOKEN` in the project's `.env` **and**
add a compose override (e.g. `docker-compose.override.yml`) that appends
`--ServerApp.token=${JUPYTER_TOKEN}` to the `jupyter` service command —
the default compose file intentionally does not bake this in.

Treat `JUPYTER_TOKEN` as a secret (same as `POSTGRES_PASSWORD` and
`DJANGO_SECRET_KEY`): never commit it, and rotate it by changing `.env`
and restarting the `jupyter` service.

### Protecting the Project `.env`

The per-project `.env` (inside `APP_HOME`) ends up holding
`POSTGRES_PASSWORD`, `DJANGO_SECRET_KEY`, `DJANGO_SUPERUSER_PASSWORD`, and
optionally `JUPYTER_TOKEN`. Treat the whole file as a secret: keep it out
of version control, restrict its file permissions, and back it up
separately from the source tree.

## Services Overview

Chembience ships several services, all wired together via `docker-compose.yml`:

| Service      | Directory    | Purpose                                                 |
| ------------ | ------------ | ------------------------------------------------------- |
| `django`     | `django/`    | Main Django web app.                                    |
| `fastapi`    | `fastapi/`   | Async REST API.                                         |
| `jupyter`    | `jupyter/`   | JupyterLab environment with RDKit + Postgres pre-wired. |
| `rdkit`      | `rdkit/`     | RDKit interactive one-shot Python shell.                |
| `postgres`   | `postgres/`  | PostgreSQL 18 with the RDKit cartridge.                 |

For all services, the connection to the database is wired via environment variables, that can
be imported via the shared chembience python module. The package also let you import a
readily configured SqlAlchemy engine.

```python
from chembience import db
dir(db)
['Base', 'POSTGRES_HOST', 'POSTGRES_NAME', 'POSTGRES_PASSWORD', 'POSTGRES_PORT', 'POSTGRES_USER', 'SQLALCHEMY_DATABASE_URL', 'SessionLocal', '__builtins__', '__cached__', '__doc__', '__file__', '__loader__', '__name__', '__package__', '__spec__', 'create_engine', 'declarative_base', 'engine', 'get_db', 'init_db', 'os', 'sessionmaker']
```

### Repository Layout

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

Per-app helper scripts located in their app directories:

| App       | Scripts |
|-----------| ------- |
| `django`  | `django/django-init`, `django/django-manage-py`, `django/psql` |
| `fastapi` | `fastapi/app/fastapi-init`, `fastapi/app/db_backup`, `fastapi/app/db_cleanup`, `fastapi/app/db_restore` |
| `jupyter` | `jupyter/app/jupyter-init` |
| `rdkit`   | `rdkit/app/rdkit-init`, `rdkit/app/run`, `rdkit/app/shell` |

## Development

For more detailed information, see:
- [CLAUDE.md](CLAUDE.md): Development guide and common commands.
- [AGENTS.md](AGENTS.md): Information for AI agents and high-level overview.
- [LICENSE](LICENSE): BSD 3-Clause License.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
