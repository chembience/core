# Chembience Development Guide

## Build & Run Commands
- Build all services: `docker compose build` (run from `core/`)
- Start services: `docker compose up -d`
- Stop services: `docker compose down`
- View logs: `docker compose logs -f`
- Run Django management commands: `docker compose exec django python manage.py <command>`
- Shell access (Django): `docker compose exec django /bin/bash`
- Shell access (RDKit): `docker compose exec rdkit /bin/bash`

## Code Style Guidelines
- **Python**: Follow PEP 8. Use 4 spaces for indentation.
- **Django**: Standard Django project layout. Settings are expected in `appsite/settings.py`.
- **Docker**: Use environment variables for configuration. Multi-stage builds are preferred.
- **Naming**: Use `snake_case` for variables/functions, `PascalCase` for classes.

## Project Architecture
- `core/`: Root of the core platform.
- `core/django/`: Contains the Django application logic and its Docker setup.
- `core/rdkit/`: Contains RDKit-related scripts and environment.
- `core/postgres/`: Database configuration and initialization scripts.
- `.env`: Global environment configuration.
