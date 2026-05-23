# Information for AI Agents

Welcome, AI agent. This document provides a high-level overview of the Chembience
project to help you navigate and contribute effectively.

## Project Context
Chembience is a specialized platform for chemical informatics. It bundles a
Django web app, a FastAPI service, a JupyterLab environment, an RDKit shell,
and a PostgreSQL database with the RDKit cartridge — all wired together via a
single `docker-compose.yml`.

## Service Overview
All services are defined in `core/docker-compose.yml` and share the
`app-network` Docker network.

- **Django (`core/django`)**: Main web service. Runs `gunicorn src.wsgi:application`.
  Container `working_dir` is `/home/app/src/`. Host app code lives under
  `${APP_HOME}/src/` (bind-mounted into the container).
- **FastAPI (`core/fastapi`)**: Async REST API. Runs `uvicorn src.main:app`.
  Same `src/` layout convention as Django.
- **Jupyter (`core/jupyter`)**: JupyterLab pre-wired with RDKit + Postgres.
- **RDKit (`core/rdkit`)**: Conda-based RDKit image. Two compose services use it:
  - `rdkit`: interactive one-shot Python shell (`tty: true`, `command: python`).
  - `rdkit-app`: long-running sidecar (`tail -f /dev/null`) that keeps an
    RDKit environment alive with `${APP_HOME}` mounted, for ad-hoc scripts.
- **Postgres (`core/postgres`)**: PostgreSQL 18 with the RDKit cartridge.
- **Test App (`core/django/app/django-rdkit-test-app`)**: A reference Django
  application integrated during initialization to verify RDKit functionality.
  It is a valid, intentionally retained smoke-test app — do not remove it.

## Navigation Map
- `core/docker-compose.yml`: Authoritative definition of all services and how
  they interact.
- `core/.env` (and `core/.env.example`): Central configuration. Check these
  for environment variables (`DJANGO_*`, `FASTAPI_*`, `JUPYTER_*`,
  `POSTGRES_*`, `CHEMBIENCE_*`, `APP_HOME`, etc.).
- `core/build`, `core/remove`, `core/psql`, `core/test-build-all`: Top-level
  helper scripts (run from `core/`).
- Per-service init helpers:
  - `core/django/django-init`, `core/django/django-manage-py`, `core/django/psql`
  - `core/fastapi/app/fastapi-init`, `core/fastapi/app/db_backup`,
    `core/fastapi/app/db_cleanup`, `core/fastapi/app/db_restore`
  - `core/jupyter/app/jupyter-init`
  - `core/rdkit/app/rdkit-init`, `core/rdkit/app/run`, `core/rdkit/app/shell`
- Dependencies:
  - Django/FastAPI: pip-based, declared inside their respective images and the
    per-project `src/` directory.
  - RDKit and Postgres images: dependencies are **conda-driven** via
    `condaforge/miniforge3` and the `rdkit_version` build arg in
    `docker-compose.yml`, not a pip `requirements.txt`.
- `core/django/Dockerfile` (entrypoint installed at `/docker-entrypoint.sh`
  inside the image) is the Django container entrypoint.

## Interaction Guidelines
- **Line Endings**: All files MUST use Linux line endings (`LF`). This is
  enforced by `.gitattributes` (`* text eol=lf`). Windows line endings (`CRLF`)
  can cause issues in Docker containers and shell scripts.
- **Docker is the primary execution environment.** Assume commands should be
  run via `docker compose exec <service> ...` from `core/`.
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
