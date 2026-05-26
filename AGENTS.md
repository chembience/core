# Information for AI Agents

Welcome, AI agent. This document provides a high-level overview of the Chembience
project to help you navigate and contribute effectively.

## Project Context
Chembience is a specialized platform for chemical informatics. It bundles a
Django web app, a FastAPI service, a JupyterLab environment, an RDKit shell,
and a PostgreSQL database with the RDKit cartridge — all wired together via a
single `docker-compose.yml`.

## Service Overview
All services are defined in `docker-compose.yml` (at the project root) and
share the `app-network` Docker network. The compose file also declares an
external `chembience-network` (currently not attached to any service) for
optional cross-stack wiring.

- **Django (`django/`)**: Main web service. Runs `gunicorn src.wsgi:application`.
  Container `working_dir` is `/home/app/src/`. Host app code lives under
  `${APP_HOME}/src/` (bind-mounted into the container).
- **FastAPI (`fastapi/`)**: Async REST API. Container `working_dir` is
  `/home/app/src/` and the entrypoint runs `uvicorn main:app` from there
  (i.e. `src/main.py`). Same `src/` layout convention as Django.
- **Jupyter (`jupyter/`)**: JupyterLab pre-wired with RDKit + Postgres.
- **RDKit (`rdkit/`)**: Conda-based RDKit image. Two compose services use it:
  - `rdkit`: interactive one-shot Python shell (`tty: true`, `command: python`).
  - `rdkit-app`: long-running sidecar (`tail -f /dev/null`) that keeps an
    RDKit environment alive with `${APP_HOME}` mounted, for ad-hoc scripts.
- **Postgres (`postgres/`)**: PostgreSQL 18 with the RDKit cartridge.
- **Test App (`django/app/django-rdkit-test-app`)**: A reference Django
  application integrated during initialization to verify RDKit functionality.
  It is a valid, intentionally retained smoke-test app — do not remove it.

## Navigation Map
- `docker-compose.yml`: Authoritative definition of all services and how
  they interact.
- `docker-compose.dev.yml`: Development overlay applied on top of the
  main compose file.
- `llms.txt`: Project metadata for LLM-based tooling.
- `.env` (and `.env.example`): Central configuration. Check these
  for environment variables (`DJANGO_*`, `FASTAPI_*`, `JUPYTER_*`,
  `POSTGRES_*`, `CHEMBIENCE_*`, `APP_HOME`, etc.). Additional build-time
  args used by `docker-compose.yml` include `CONDA_PY`, `RDKIT_VERSION`,
  `APT_MIRROR`, `CONDA_MIRROR`, `CHEMBIENCE_UID`/`CHEMBIENCE_GID`,
  `GUNICORN_WORKERS`, and `UVICORN_WORKERS`.
- `share/chembience/`: Shared Python module imported by services
  (`from chembience import db`) to access a pre-configured SQLAlchemy
  engine and Postgres connection settings.
- `build`, `remove`, `psql`, `test-build-all`: Top-level
  helper scripts (run from the project root).
- Per-service init helpers:
  - `django/django-init`, `django/django-manage-py`, `django/psql`
  - `fastapi/app/fastapi-init`, `fastapi/app/db_backup`,
    `fastapi/app/db_cleanup`, `fastapi/app/db_restore`
  - `jupyter/app/jupyter-init`
  - `rdkit/app/rdkit-init`, `rdkit/app/run`, `rdkit/app/shell`
- Per-app `*-configure` scripts (used for password rotation and other
  per-project configuration; see README §Secrets):
  - `django/app/django-configure`
  - `fastapi/app/fastapi-configure`
  - `jupyter/app/jupyter-configure`
  - `rdkit/app/rdkit-configure`
- Dependencies:
  - Django/FastAPI: pip-based, declared inside their respective images and the
    per-project `src/` directory.
  - RDKit and Postgres images: dependencies are **conda-driven** via
    `condaforge/miniforge3` and the `rdkit_version` build arg in
    `docker-compose.yml`, not a pip `requirements.txt`.
- `django/Dockerfile`: Django container image. The host entrypoint
  source lives at `django/docker-entrypoint.sh` and is installed in
  the image as `/docker-entrypoint.sh`.

## Interaction Guidelines
- **Line Endings**: All files MUST use Linux line endings (`LF`). This is
  enforced by `.gitattributes` (`* text eol=lf`). Windows line endings (`CRLF`)
  can cause issues in Docker containers and shell scripts.
- **Docker is the primary execution environment.** Assume commands should be
  run via `docker compose exec <service> ...` from the project root.
- **Django migrations**: When modifying Django models, generate and commit
  migrations:
  `docker compose exec django python manage.py makemigrations`
  `docker compose exec django python manage.py migrate`
- **Cheminformatics domain**: Data often involves SMILES strings, InChI, and
  complex molecular representations. Be careful with encoding, normalization,
  and database round-trips.
- **Do not commit runtime artifacts**: `test-builds/` and Postgres data
  directories must stay out of version control (already in `.gitignore`).
- **Secrets**: `DJANGO_SECRET_KEY` is auto-generated on first `./build` and
  persisted in the per-project `.env`. Treat that file as a secret. See
  README §Secrets.
