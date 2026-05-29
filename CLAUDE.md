# Chembience Development Guide

## Build & Run Commands
Run from the project root (where `docker-compose.yml` lives) unless noted.

### Lifecycle
- Build all images: `docker compose build`
- Bootstrap a new app: `./build <type> <target>` (e.g. `./build django myapp`)
  - `<type>`: `django`, `fastapi`, `jupyter`, or `rdkit`
  - Custom parent dir: `./build django myapp -d /path/to/dir`
- Tear down an app: `./remove <target>` (or `./remove <target> -d /path/to/dir`)
- Start services: `docker compose up -d`
- Stop services: `docker compose down`
- Tail logs: `docker compose logs -f [<service>]`
- Dev overlay: apply `docker-compose.dev.yml` on top of the main compose
  file when needed, e.g.
  `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`.
- Rotate the Postgres password / reconfigure a project: use the per-app
  `*-configure` script inside the project directory
  (`django-configure`, `fastapi-configure`, `jupyter-configure`,
  `rdkit-configure`). See README §Secrets.

### Django
- Manage commands: `docker compose exec django python manage.py <command>`
- Migrations: `docker compose exec django python manage.py makemigrations`
  / `docker compose exec django python manage.py migrate`
- Run tests: `docker compose exec django python manage.py test <app_name>`
- Shell: `docker compose exec django /bin/bash`
- DB shell: `django/psql`

### FastAPI
- Shell: `docker compose exec fastapi /bin/bash`
- Logs: `docker compose logs -f fastapi`
- Helpers: `fastapi/app/fastapi-init`,
  `fastapi/app/db_backup`,
  `fastapi/app/db_restore`,
  `fastapi/app/db_cleanup`
- Entry: `uvicorn main:app --host 0.0.0.0 --port 8000` (run from
  `working_dir=/home/app/src/`, i.e. `src/main.py`)

### Jupyter
- Shell: `docker compose exec jupyter /bin/bash`
- Logs: `docker compose logs -f jupyter`
- Open the lab: prefer running the per-app init helper, which prints the
  access URL (with token when available): `./jupyter-init` from inside a
  generated app directory.
- Token auth is enabled by default. To disable it in development, apply the
  provided overlay: `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`.
- To pin a stable token, set `JUPYTER_TOKEN` in `.env` and add a small compose
  override that appends `--ServerApp.token=${JUPYTER_TOKEN}` to the `jupyter`
  command.

### RDKit
- Interactive shell (one-shot): `docker compose run --rm rdkit`
- Long-running sidecar shell: `docker compose exec rdkit-app /bin/bash`
- Helpers: `rdkit/app/run`, `rdkit/app/shell`

### Postgres
- `psql` shell: `./psql` (from the project root)
- Direct: `docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_NAME`
- Note: No host port is published by default; connect over the internal
  network on `postgres:5432` or create your own compose override if you need
  host access.

## Tuning
- `GUNICORN_WORKERS` (Django) and `UVICORN_WORKERS` (FastAPI) can be set in
  `.env` to override the defaults baked into `docker-compose.yml`.

## Code Style Guidelines
- **Line Endings**: Use Linux line endings (`LF`) for all files. Enforced by
  `.gitattributes`.
- **Python**: Follow PEP 8. Use 4 spaces for indentation.
- **Django**: Standard Django project layout. Settings live at
  `src/src/settings.py` inside the bind-mounted `${APP_HOME}`.
- **FastAPI**: Entry module is `src/main.py` (`app = FastAPI(...)`).
- **Docker**: Use environment variables for configuration. Multi-stage builds
  are preferred. All Python-based images utilize **micromamba** (mamba) for
  dependency management and to keep image sizes small. Never bake secrets into images.
- **Naming**: `snake_case` for variables/functions, `PascalCase` for classes.

## Project Architecture
- Project root: top-level of the Chembience platform (contains
  `docker-compose.yml`).
- `django/`: Django service + Dockerfile. Reference test app at
  `django/app/django-rdkit-test-app` (kept intentionally as a
  RDKit smoke-test app).
- `fastapi/`: FastAPI service + Dockerfile.
- `jupyter/`: JupyterLab service + Dockerfile + notebooks.
- `rdkit/`: RDKit base image and helper scripts.
- `postgres/`: PostgreSQL (RDKit cartridge) image and init scripts.
- `share/chembience/`: Shared Python module imported by services
  (`from chembience import db`) providing a pre-configured SQLAlchemy
  engine, session factory, and Postgres connection settings.
- `.env`: Global environment configuration (see `.env.example`).
- `docker-compose.yml`: Authoritative service wiring.
- `docker-compose.dev.yml`: Optional development overlay.
