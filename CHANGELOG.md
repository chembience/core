# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1] - 2026-06-03

### Changed
- Switched to `mamba` as the primary build system for faster image builds.
- Reduced Docker image sizes by optimizing layers and dependencies.
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
