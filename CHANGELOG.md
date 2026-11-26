# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.3-pre1] - 2026-11-26

### Changed
- Bumped release version to 0.6.3-pre1, including the Helm chart
  `appVersion` and default RDKit PostgreSQL image tags.
- `./test` now verifies that Helm chart and values versions match `VERSION`.
- Pinned the ShellCheck GitHub Action to release 2.0.0 by commit SHA, and run
  the Lint and Compose Validate workflows on `dev/*` branches too.
- `./test` runs ShellCheck (warning severity, matching CI) when `shellcheck`
  is installed.
- Bumped `pytest-asyncio` to 1.5.0 in the FastAPI core image. The upstream
  `asyncio.get_event_loop_policy` deprecation warning (removal in Python 3.16)
  remains until a pytest-asyncio release stops calling it.
- Reduced `postgres/postgresql.conf` to the 16 settings Chembience sets; all
  other parameters keep PostgreSQL defaults as before.
- Moved the duplicated entrypoint logic (runtime-mode normalization, app
  user/group setup, ownership fixes, file sync, PROD bundle sync, and ignore
  file seeding) into a shared `share/entrypoint/helpers.sh` sourced by all four
  core images.
- **Behavior change:** shipped helper scripts (`*-configure`,
  `*-prepare-prod`, `*-init`, `psql`, `PROD/db-*`, RDKit `run`/`shell`) are now
  refreshed from the image on every development start for all app types, as
  FastAPI already did. Upgrading `CHEMBIENCE_VERSION` now delivers script
  fixes to existing Django, JupyterLab, and RDKit apps; local edits to these
  scripts are overwritten. Configuration and documentation files are still
  copied only when missing.
- Moved the shared `*-prepare-prod` implementation into
  `prod-tools/lib/prepare-prod.sh`, shipped to generated apps as
  `PROD/lib/prepare-prod.sh` (`prod/lib/` for a legacy `prod/` directory) and
  refreshed with the scripts. The four per-app scripts shrink from about 300
  lines to 40-70 lines of settings and hooks; generated bundles, Compose
  commands, and messages are unchanged. Commit `PROD/lib/` with the app; the
  shipped `.gitignore` now re-includes it despite its Python `lib/` rule, and
  the entrypoint adds `!PROD/lib/` to existing app `.gitignore` files.
- JupyterLab and RDKit production preparation now stop the bundled stack
  when the PostgreSQL readiness check fails, as Django and FastAPI already did.

- Made `AGENTS.md` the single, tool-neutral agent guide for the repository and
  each generated app type; `CLAUDE.md` files now import it (`@AGENTS.md`), and
  `./test` enforces that. The guides add working contexts, a change-to-
  verification table, a definition of done, and guardrails for destructive
  commands. Rewrote the outdated `llms.txt`.
- `./test` reports checks whose tools are missing (`helm`, `docker`,
  `shellcheck`, PyYAML) as SKIPPED with a closing summary instead of aborting;
  the new `--strict` flag (used in CI) fails on skips. The test scripts no
  longer need ripgrep.
- Added `tests/compare-prepare-prod.sh <git-rev>` to prove that changes to
  `*-prepare-prod` or `prod-tools/lib/` preserve behavior.
- Added `./release` (`check`, `prepare <version>`, `start <version>`), which
  performs all mechanical release steps (version references, CHANGELOG
  section, README release row, validation, commit) and never tags, pushes, or
  publishes. `./release check` runs in `./test` and also rejects released
  version strings left in docs; the generated-app README examples now use
  app-owned image tags, and the CHANGELOG uses a bare `## [Unreleased]`
  heading. The release procedure is documented in `AGENTS.md`.
- Added shared Claude Code project settings (`.claude/settings.json`): allowed
  validation commands, denied destructive commands, and a PostToolUse hook that
  lints edited shell scripts with `bash -n` and ShellCheck.

### Fixed
- Jupyter and RDKit `*-prepare-prod` now wait up to 120 seconds (was 30) for
  the freshly initialized production PostgreSQL, matching its healthcheck
  budget, and report a timeout explicitly; slow first starts no longer abort
  preparation. Override with `PREPARE_PROD_POSTGRES_TIMEOUT`.
- RDKit apps now restore missing shipped files on each development start
  instead of only during first initialization.
- Removed unused loop variables flagged by ShellCheck in the FastAPI, Jupyter,
  and RDKit `*-configure` scripts.

## [0.6.2] - 2026-09-06

### Added
- Added isolated `PROD/` self-hosted Docker Compose bundles for Django,
  FastAPI, JupyterLab, and RDKit applications, including external-database
  Compose profiles and database maintenance helpers (`psql`, backup, restore,
  and cleanup).
- Added self-contained `PROD/k8s/` Helm bundles for all generated application
  types, with optional bundled RDKit PostgreSQL storage, Secrets, Ingress, and
  migration Jobs for Django and FastAPI.
- Added the `ghcr-k8s` production target. It bootstraps a GitHub Actions image
  publisher, publishes immutable private GitHub Container Registry images, and
  generates Helm values pinned to the pushed Git commit SHA.
- Added [Kubernetes Ingress and TLS](K8S_INGRESS.md) guidance for installing an
  Ingress controller, cert-manager, and Let's Encrypt certificates.
- Added a unified `./test` command and `./test --integration` Docker workflow;
  retained `test-build-all` as an integration-test compatibility alias.
- Added app-specific `AGENTS.md` and `CLAUDE.md` guidance files to generated
  Django, FastAPI, JupyterLab, and RDKit application roots.

### Changed
- Replaced legacy self-hosted production scripts with the per-app
  `*-configure --prod` and `*-prepare-prod` workflow. Production configuration
  is prepared in ignored `.env.prod` and copied to `PROD/.env`.
- Renamed generated application Kubernetes directories from `kubernetes` to
  `k8s` and standardized the documented Kubernetes namespace as `chembience`.
- Production helpers now derive the project name from `.env` `APP_NAME` or the
  generated app directory, and substitute it into generated deployment docs.
- Updated core RDKit to 2026.03.5 and require `CONDA_PY` and `RDKIT_VERSION` to
  match between `.env` and `.env.template` during testing.
- Refreshed root, production-bundle, application, and Kubernetes documentation
  for the current Docker Compose, GHCR, Kubernetes, TLS, migration, and
  database-access workflows.

### Fixed
- Fixed generated Kubernetes README substitution so GHCR preparation does not
  leave an otherwise clean generated application Git working tree modified.
- Added explicit namespace creation before namespaced Kubernetes Secret commands.

## [0.6.1] - 2026-08-25

### Added
- Added `VERSION` as the single source of truth for the Chembience release
  version.
- Added Docker Hub-backed `install` and local-core `build` bootstrap commands.

### Changed
- Production image-preparation helpers now pull their matching published core
  images before building source-baked application images.
- Release and validation workflows derive `CHEMBIENCE_VERSION` from `VERSION`.

## [0.6.0] - 2026-08-01

### Changed
- Renamed the root environment template from `.env.example` to `.env.template`.
- Updated build scripts, CI workflows, Dockerfiles, and documentation to use `.env.template` consistently.
- Added a release-triggered GitHub Actions workflow that publishes the reusable
  core images to Docker Hub.
- Refreshed the root contributor and agent guidance (`README.md`, `CLAUDE.md`,
  and `AGENTS.md`) to distinguish core-repository and generated-app workflows.
- Updated the Django, FastAPI, JupyterLab, and RDKit application README
  templates with current setup, database-networking, migration, and token-auth
  guidance.

## [0.5.1] - 2026-06-03

### Changed
- Switched to `mamba` as the primary build system for faster image builds, including the PostgreSQL image.
- Reduced Docker image sizes by optimizing layers and dependencies across all services.
- Updated installed `psycopg` and `psycopg-binary` dependencies to asynchrosus version 3.
- Modified container entrypoints to prevent overwriting user-edited configuration files (e.g., `.gitignore`, `.dockerignore`, `docker-compose.yml`) in `APP_HOME`.
- Disabled automatic generation of `.dist` configuration files during container startup.

### Fixed
- Many minor improvements and bug fixes across all services.

## [0.5.0] - 2026-05-27

### Added
- Initial release of the re-implemented core architecture.
- Integrated Django, FastAPI, JupyterLab, and RDKit services.
- Multi-service `docker-compose.yml` orchestration.
- Support for PostgreSQL 18 with RDKit cartridge.
- Shared Python module `chembience` for database access.
- Automated application build and setup scripts.
