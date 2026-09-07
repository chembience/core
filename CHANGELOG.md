# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
