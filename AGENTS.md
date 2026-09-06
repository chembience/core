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
- **RDKit (`rdkit/`)**: Micromamba-based RDKit image. Two compose services use it:
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
- `VERSION`: Single source of truth for the Chembience release version.
- `.env` (and `.env.template`): Central runtime configuration. Check these
  for environment variables (`DJANGO_*`, `FASTAPI_*`, `JUPYTER_*`,
  `POSTGRES_*`, `CHEMBIENCE_*`, `APP_HOME`, etc.). Additional build-time
  args used by `docker-compose.yml` include `CONDA_PY`, `RDKIT_VERSION`,
  `APT_MIRROR`, `CONDA_MIRROR`, `CHEMBIENCE_UID`/`CHEMBIENCE_GID`,
  `GUNICORN_WORKERS`, and `UVICORN_WORKERS`.
- `share/chembience/`: Shared Python module imported by services
  (`from chembience import db`) to access a pre-configured SQLAlchemy
  engine and Postgres connection settings.
- `install`, `build`, `core-build`, `remove`, `psql`, `test`, `test-build-all`:
  Top-level helper scripts (run from the project root). `test-build-all` is the
  compatibility alias for `test --integration`.
- `*/app/`: Templates copied into the root of generated applications by the
  corresponding service entrypoint. When editing a template helper or README,
  keep its commands relative to a generated application directory.
- Per-service init helpers:
  - `django/django-init`, `django/django-manage-py`, `django/psql`
  - `fastapi/app/fastapi-init`, `fastapi/app/db-backup`,
    `fastapi/app/db-cleanup`, `fastapi/app/db-restore`
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
  - RDKit and Postgres images: dependencies are **mamba-driven** via
    `mambaorg/micromamba` and the `rdkit_version` build arg in
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
- **Install vs. build**: `./install` pulls the exact published core images for
  `VERSION`; `./build` builds those core images from the local checkout and is
  the required path for source changes and CI smoke tests.
- **Testing**: Run `./test` for shell, Python, Helm, and Compose validation;
  run `./test --integration` for the complete Docker workflow. `CONDA_PY` and
  `RDKIT_VERSION` must remain identical in `.env` and `.env.template`.
- **Generated application context**: The core repository and a generated app
  use different compose files. For generated-app work, `cd` into the generated
  directory before running `docker compose`; its copied helper scripts live at
  that directory's root.
- **Jupyter token behavior**: Token auth is enabled by default. A generated
  Jupyter app persists `JUPYTER_TOKEN` in its `.env` when none is supplied;
  `jupyter-init` prints the access URL. Set that variable directly to choose a
  stable token. Use the provided `docker-compose.dev.yml` overlay to disable
  the token in development (`--ServerApp.token=''`).
- **Postgres networking**: The Postgres service is not published on a host
  port by default. All services connect over the internal Docker network at
  `postgres:5432`. Use your own compose override if host access is needed.
- **Django migrations**: When modifying Django models, generate and commit
  migrations:
  `docker compose exec django python manage.py makemigrations`
  `docker compose exec django python manage.py migrate`
- **Production targets**: `*-prepare-prod --target compose` is the default
  self-hosted Docker Compose route. `--target ghcr-k8s` bootstraps a GitHub
  Actions workflow on its first run, then generates a SHA-pinned Helm bundle
  after that commit is pushed and built. The generated app's
  `PROD/k8s/README.md` is the deployment authority; preserve
  `values.override.yaml` and Kubernetes Secrets as host-owned configuration.
- **Kubernetes database access**: For the bundled database, use `kubectl exec`
  against the generated PostgreSQL Pod rather than publishing a database port.
  The app-specific `PROD/k8s/README.md` contains the exact command.
- **Cheminformatics domain**: Data often involves SMILES strings, InChI, and
  complex molecular representations. Be careful with encoding, normalization,
  and database round-trips.
- **Do not commit runtime artifacts**: `test-builds/` and Postgres data
  directories must stay out of version control (already in `.gitignore`).
- **Secrets**: `DJANGO_SECRET_KEY` is auto-generated on first `./install` or `./build` and
  persisted in the per-project `.env`. Treat that file as a secret. See
  README §Secrets.
- **App-context guidance**: `*/app/AGENTS.md` and `*/app/CLAUDE.md` are copied
  into generated applications. Keep these templates scoped to the corresponding
  app type and update them when a generated-app workflow changes.
