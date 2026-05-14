# Information for AI Agents

Welcome, AI agent. This document provides a high-level overview of the Chembience project to help you navigate and contribute effectively.

## Project Context
Chembience is a specialized platform for chemical informatics. It uses Django for the web interface and API, and RDKit for chemical data processing.

## Service Overview
- **Django (`core/django`)**: Main web service. Entry point is `docker-entrypoint.sh`. App code is in `app/`.
- **RDKit (`core/rdkit`)**: Informatics engine. Provides specialized chemical processing capabilities.
- **Postgres (`core/postgres`)**: Database storing chemical structures and metadata.

## Navigation Map
- `core/docker-compose.yml`: Defines how all services interact.
- `core/.env`: Central configuration. Check this for environment variables.
- `core/django/app/requirements.txt`: Python dependencies for the web service.
- `core/rdkit/requirements.txt`: Python dependencies for the RDKit service.

## Interaction Guidelines
- When modifying Django code, ensure migrations are handled.
- Docker is the primary execution environment. Assume commands should be run via `docker compose exec`.
- Respect the Cheminformatics domain: data often involves SMILES strings, InChI, and complex molecular representations.
