# Chembience Development Guide

## Build & Run Commands
Run from `core/` unless noted.

### Lifecycle
- Build all images: `docker compose build`
- Bootstrap a new app: `./build <type> <target>` (e.g. `./build django myapp`)
  - `<type>`: `django`, `fastapi`, `jupyter`, or `rdkit`
  - Custom parent dir: `./build django myapp -d /path/to/dir`
- Tear down an app: `./remove <target>` (or `./remove <target> -d /path/to/dir`)
- Start services: `docker compose up -d`
- Stop services: `docker compose down`
- Tail logs: `docker compose logs -f [<service>]`

### Django
- Manage commands: `docker compose exec django python manage.py <command>`
- Migrations: `docker compose exec django python manage.py makemigrations`
  / `docker compose exec django python manage.py migrate`
- Run tests: `docker compose exec django python manage.py test <app_name>`
- Shell: `docker compose exec django /bin/bash`
- DB shell: `core/django/psql`

### FastAPI
- Shell: `docker compose exec fastapi /bin/bash`
- Logs: `docker compose logs -f fastapi`
- Helpers: `core/fastapi/app/fastapi-init`,
  `core/fastapi/app/db_backup`,
  `core/fastapi/app/db_restore`,
  `core/fastapi/app/db_cleanup`
- Entry: `uvicorn src.main:app --host 0.0.0.0 --port 8000`

### Jupyter
- Shell: `docker compose exec jupyter /bin/bash`
- Logs: `docker compose logs -f jupyter`
- Open the lab: `http://localhost:${JUPYTER_CONNECTION_PORT:-8888}/`
  (token is disabled by default in `docker-compose.yml`).

### RDKit
- Interactive shell (one-shot): `docker compose run --rm rdkit`
- Long-running sidecar shell: `docker compose exec rdkit-app /bin/bash`
- Helpers: `core/rdkit/app/run`, `core/rdkit/app/shell`

### Postgres
- `psql` shell: `./psql` (from `core/`)
- Direct: `docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_NAME`

## Tuning
- `GUNICORN_WORKERS` (Django) and `UVICORN_WORKERS` (FastAPI) can be set in
  `core/.env` to override the defaults baked into `docker-compose.yml`.

## Code Style Guidelines
- **Line Endings**: Use Linux line endings (`LF`) for all files. Enforced by
  `.gitattributes`.
- **Python**: Follow PEP 8. Use 4 spaces for indentation.
- **Django**: Standard Django project layout. Settings live at
  `src/src/settings.py` inside the bind-mounted `${APP_HOME}`.
- **FastAPI**: Entry module is `src/main.py` (`app = FastAPI(...)`).
- **Docker**: Use environment variables for configuration. Multi-stage builds
  are preferred. Never bake secrets into images.
- **Naming**: `snake_case` for variables/functions, `PascalCase` for classes.

## Project Architecture
- `core/`: Root of the core platform.
- `core/django/`: Django service + Dockerfile. Reference test app at
  `core/django/app/django-rdkit-test-app` (kept intentionally as a
  RDKit smoke-test app).
- `core/fastapi/`: FastAPI service + Dockerfile.
- `core/jupyter/`: JupyterLab service + Dockerfile + notebooks.
- `core/rdkit/`: RDKit base image and helper scripts.
- `core/postgres/`: PostgreSQL (RDKit cartridge) image and init scripts.
- `core/.env`: Global environment configuration (see `.env.example`).
- `core/docker-compose.yml`: Authoritative service wiring.
