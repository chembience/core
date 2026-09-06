# Chembience Development Guide

## Build & Run Commands
Run from the project root (where `docker-compose.yml` lives) unless noted.

### Lifecycle
- Build all images: `docker compose build`
- Install a new app from published core images: `./install <type> <target>`
  (e.g. `./install django myapp`)
- Bootstrap an app with locally built core images: `./build <type> <target>`
  - `<type>`: `django`, `fastapi`, `jupyter`, or `rdkit`
  - Both commands accept `-d /path/to/dir` for a custom parent directory.
  - The default setup run exits after initialization; work with the generated
    app from its own directory. Use `--no-quit` to keep that setup run attached.
- Tear down an app: `./remove <target>` (or `./remove <target> -d /path/to/dir`). It aborts once production preparation creates `PROD/.env`; use `--force-prod` only after confirming that the production stack may be brought down.
- Validate the checkout: `./test`; run the full Docker integration suite with
  `./test --integration` (`test-build-all` is a compatibility alias for the
  latter).
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
  `fastapi/app/db-backup`,
  `fastapi/app/db-restore`,
  `fastapi/app/db-cleanup`
- Entry: `uvicorn main:app --host 0.0.0.0 --port 8000` (run from
  `working_dir=/home/app/src/`, i.e. `src/main.py`)

### Jupyter
- Shell: `docker compose exec jupyter /bin/bash`
- Logs: `docker compose logs -f jupyter`
- Open the lab: run `./jupyter-init` inside a generated app directory; it
  validates the environment and prints the access URL.
- Token auth is enabled by default. The generated app persists a token in its
  `.env` when one is not supplied. To disable it in development, apply the
  provided overlay: `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`.
- To choose a stable token, set `JUPYTER_TOKEN` in the generated app's `.env`;
  no compose override is needed.

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
- **Generated apps**: Treat the files in `*/app/` as templates. Verify a
  generated project when changing them, because entrypoints copy helpers and
  README files into the project directory during development-mode bootstrap.
- **Release version**: `VERSION` is the single source of truth. `install` and
  `build` derive `CHEMBIENCE_VERSION` in `.env`; do not edit that key manually.
- **Core build versions**: Keep `CONDA_PY` and `RDKIT_VERSION` identical in
  `.env` and `.env.template`; `./test` enforces this.
- **Production delivery**: Use `*-prepare-prod --target compose` for a
  self-hosted Docker Compose bundle. For a Docker-free Kubernetes host use
  `--target ghcr-k8s`: the first run creates a GitHub Actions workflow; commit
  and push it, wait for the image build, then rerun from the clean commit to
  write SHA-pinned Helm values. Treat `PROD/k8s/values.override.yaml` and
  Kubernetes Secrets as host-owned and do not commit them.

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
- `.env`: Global environment configuration (see `.env.template`).
- `docker-compose.yml`: Authoritative service wiring.
- `docker-compose.dev.yml`: Optional development overlay.
- `K8S_INGRESS.md`: Ingress-controller, TLS, and cert-manager guide for public
  Kubernetes deployments.
- `*/app/AGENTS.md`, `*/app/CLAUDE.md`: Guidance copied to generated app roots;
  keep these app-specific templates aligned with generated workflows.
