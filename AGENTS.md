# Chembience Core: Guide for AI Agents and Contributors

This is the single, tool-neutral source of agent guidance for this repository
(`CLAUDE.md` imports it). Keep it accurate: every command and path below must
exist.

Chembience bundles a containerized cheminformatics stack: Django, FastAPI,
JupyterLab, and RDKit services plus PostgreSQL 18 with the RDKit cartridge.
This repository builds the **core images** and the **templates** from which
`./install` and `./build` generate standalone applications.

## Two working contexts

Decide first which one you are in; commands differ.

| | Core repository (this checkout) | Generated application |
|---|---|---|
| Location | directory with `VERSION` and `core-build` | `$HOME/<target>` by default, or `-d <dir>` gives `<dir>/<target>` |
| Compose file | root `docker-compose.yml` (builds core images) | the app's own `docker-compose.yml` |
| Typical work | images, entrypoints, templates in `*/app/`, prod tooling, tests | application code, migrations, notebooks, production preparation |
| Guidance | this file | the app's `AGENTS.md` (from `*/app/AGENTS.md`) |

Root-level `docker compose exec <service>` only works while a bootstrap run is
attached (`./build ... --no-quit`). For application work, `cd` into the
generated app and use its compose file and helper scripts.

## Commands (core repository)

- Validate the checkout: `./test` (fast; checks whose tools are missing are
  reported as SKIPPED), `./test --strict` (fails on any skip; used by CI), and
  `./test --integration` (builds every image and runs dev and production flows
  for all app types; slow, run it in the background). `test-build-all` is a
  compatibility alias for `./test --integration`.
- Prove a prepare-prod refactor preserves behavior:
  `tests/compare-prepare-prod.sh <base-git-rev>`.
- Build core images: `docker compose build`.
- Generate an app from local images: `./build <type> <target>`; from the
  published images for `VERSION`: `./install <type> <target>`. `<type>` is
  `django`, `fastapi`, `jupyter`, or `rdkit`; `-d /path/to/dir` sets the parent
  directory; `--no-quit` keeps the setup run attached. Source changes require
  `./build`.
- Remove a generated app: `./remove <target> [-d /path/to/dir]` (see
  Guardrails).
- Postgres publishes no host port; services reach it at `postgres:5432` on the
  internal network. `./psql` (copied into every app) opens a shell in the
  running stack of the current directory.

## Commands (generated application, run from its directory)

- Django: `./django-init`; `./django-manage-py <command>` runs `manage.py` in
  the container (e.g. `makemigrations`, `migrate`, `test <app_name>`); `./psql`.
- FastAPI: `docker compose up -d && ./fastapi-init`; tests with
  `docker compose exec fastapi pytest`; Alembic revisions with
  `./fastapi-makemigrations "description"` and `./fastapi-migrate`; DB tools
  `./psql`, `./db-backup`, `./db-restore`, `./db-cleanup`.
- JupyterLab: `docker compose up -d`, then `./jupyter-init` prints the access
  URL. Token auth is on by default (the token is persisted in `.env`; set
  `JUPYTER_TOKEN` for a stable one). The core `docker-compose.dev.yml` overlay
  disables the token for development.
- RDKit: `./rdkit-init`, `./run script.py`, `./shell`, `./psql`.
- Configuration and password rotation: `./<type>-configure` (README §Secrets);
  `./<type>-configure --prod` creates `.env.prod`.
- Production: `./<type>-prepare-prod --target compose` (self-hosted bundle in
  `PROD/`) or `--target ghcr-k8s` (the first run writes a GitHub Actions
  workflow; commit, push, wait for the image build, then rerun from the clean
  commit to write SHA-pinned Helm values). `PROD/k8s/README.md` is the
  deployment authority; `PROD/k8s/values.override.yaml` and Kubernetes Secrets
  are host-owned and never committed.
- Tuning: `GUNICORN_WORKERS` (Django) and `UVICORN_WORKERS` (FastAPI) in `.env`.

## How template changes reach generated apps

Each core image copies its `*/app/*` templates, and its `docker-entrypoint.sh`
syncs them into the app on every development start
(`share/entrypoint/helpers.sh`):

- Config and documentation files (`docker-compose.yml`, `Dockerfile*`,
  `README.md`, `AGENTS.md`, `CLAUDE.md`, `requirements.txt`, `PROD/compose*.yaml`)
  are copied **only if missing**; user edits survive, so existing apps do not
  receive template updates to these files.
- Helper scripts (`*-configure`, `*-prepare-prod`, `*-init`, `psql`, `PROD/db-*`,
  RDKit `run`/`shell`) and `PROD/lib/prepare-prod.sh` are **always refreshed**.
  The per-app `*-prepare-prod` scripts are thin; the implementation is
  `prod-tools/lib/prepare-prod.sh`, so change shared behavior there.

Write template commands relative to the generated app directory.

## Verification: what to run for which change

| Change | Required verification |
|---|---|
| Documentation only | Check that every command and path you mention exists |
| Shell scripts, Helm charts, compose files, `.env.template` keys | `./test` |
| `*-prepare-prod`, `prod-tools/lib/` | `./test` and `tests/compare-prepare-prod.sh <base-rev>` (identical unless the behavior change is intended) |
| `*/Dockerfile`, `*/docker-entrypoint.sh`, `share/entrypoint/`, `*/app/*` templates, image `requirements.txt` / `environment.yml` | `./test --integration` |
| Release version, CHANGELOG headings, README release table | never by hand: use `./release` (see Releases); `./release check` runs in `./test` |
| `CONDA_PY` / `RDKIT_VERSION` | change `.env` and `.env.template` together (enforced by `./test`) |

## Releases

`./release` does all mechanical release work deterministically; it never tags,
pushes, merges, or publishes.

- During development, `CHANGELOG.md` starts with a bare `## [Unreleased]`
  section and `VERSION` holds the target version (e.g. `X.Y.Z-pre1`).
- `./release check` (read-only, part of `./test`) verifies that `VERSION`, the
  Helm chart `appVersion`, and the `core-rdkit-postgres` values tags agree; that
  CHANGELOG sections are well-formed, dated, and ordered; that the README
  release table matches every stable CHANGELOG release; and that no other
  tracked file still mentions a released version (use placeholders such as
  `X.Y.Z` in docs, or derive the value from `VERSION`).
- Cut a release from a clean tree on the development branch:
  - stable: `./release prepare X.Y.Z --summary "One line for the README table"`
  - pre-release: `./release prepare X.Y.Z-pre1` (no README row)

  It creates `release/<version>`, renames `[Unreleased]` to
  `[<version>] - <today>` (override with `--date`), updates every version
  reference, adds the README row for stable versions, runs `./release check`
  and `./test`, and commits `Release <version>`.
- Begin the next cycle after the release is merged:
  `./release start X.Y.Z-pre1` with the next version (bumps every version reference, opens an empty
  `[Unreleased]` section, commits).

**Agents stop after `prepare` (or `start`) and report.** Only a maintainer
pushes the release branch, merges it into `main`, and publishes the GitHub
Release `v<version>` (marked as pre-release for `-preN` versions). Publishing
triggers `.github/workflows/publish-dockerhub.yml`, which pushes the Docker Hub
images (stable releases also move `latest`), and mints the Zenodo DOI; neither
can be undone.

## Definition of done

- The verification above passed. A run that reports SKIPPED checks is not full
  coverage; say which checks were skipped.
- `CHANGELOG.md` has an entry under the open `[Unreleased]` section, with
  behavior changes labeled as such.
- Generated-app guidance (`*/app/AGENTS.md`, `*/app/README.md`) matches any
  changed generated workflow.
- LF line endings (`.gitattributes`), no secrets in files or images, and no
  runtime artifacts (`test-builds/`, Postgres data) committed.

## Guardrails: ask the user first

Never run these to "clean up" or "fix" something without explicit
confirmation; they destroy data or affect running or published systems:

- `./remove` (it refuses once `PROD/.env` exists; `--force-prod` overrides that
  and brings the production stack down).
- `docker compose down -v` / `--volumes`, `docker volume rm` (database data).
- `./db-restore`, `./db-cleanup`, `PROD/db-restore`, `PROD/db-cleanup`.
- Answering overwrite prompts of `*-configure --prod`; editing `.env`,
  `.env.prod`, or `PROD/.env` secrets.
- Pushing branches, images, or tags; merging into `main`; publishing GitHub
  Releases; `helm upgrade`/`helm uninstall` or `kubectl` against real clusters.

## Conventions

- Python: PEP 8, 4-space indentation; `snake_case` functions and variables,
  `PascalCase` classes.
- Shell: Bash with `set -euo pipefail` in scripts; ShellCheck-clean at warning
  severity with `-e SC1091` (the CI setting).
- Docker: configuration through environment variables, never baked-in secrets;
  Python images use micromamba; multi-stage builds where useful.
- In a generated app, Django settings live at `src/src/settings.py`; the
  FastAPI entry module is `src/main.py` (`app = FastAPI(...)`).
- `VERSION` is the single source of the release version; `install` and `build`
  derive `CHEMBIENCE_VERSION` in `.env` from it. Do not edit that key manually.
- Cheminformatics data (SMILES, InChI, molfiles) is sensitive to encoding and
  normalization; preserve exact strings across database round-trips.

## Repository map

- `docker-compose.yml`: core image builds and bootstrap services;
  `docker-compose.dev.yml`: development overlay (e.g. Jupyter without token).
- `django/`, `fastapi/`, `jupyter/`, `rdkit/`: core image `Dockerfile`,
  `docker-entrypoint.sh`, and `app/` templates (the app's `AGENTS.md`,
  `CLAUDE.md`, `k8s/` chart values, `PROD/` compose files). The RDKit image is
  the base of the other three.
- `django/app/django-rdkit-test-app`: intentionally retained RDKit smoke-test
  Django app; do not remove it.
- `postgres/`: PostgreSQL + RDKit cartridge image, `postgresql.conf`,
  `pg_hba.conf`.
- `share/chembience/`: shared Python package (`from chembience import db`:
  SQLAlchemy engine, sessions, connection settings; Django superuser helper).
- `share/entrypoint/helpers.sh`: shell helpers sourced by all entrypoints.
- `prod-tools/`: files shipped into generated apps' `PROD/`: database tools,
  `lib/prepare-prod.sh`, the Helm `k8s/chart-base`, and its render test.
- `tests/`: `test-prod-env-workflow.sh`, `test-integration.sh`,
  `compare-prepare-prod.sh`, `test_release.py`.
- `install`, `build`, `core-build`, `remove`, `psql`, `test`, `release`:
  top-level scripts.
- `.claude/`: shared Claude Code settings and a shell-lint hook.
- `K8S_INGRESS.md`: Ingress controller, TLS, and cert-manager guide.
- `llms.txt`: machine-readable project index.
