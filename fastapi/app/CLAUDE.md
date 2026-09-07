# FastAPI App Development Guide

Run commands from this generated app directory.

- Start and initialize: `docker compose up -d && ./fastapi-init`
- Tests: `docker compose exec fastapi pytest`
- New Alembic revision: `./fastapi-makemigrations "description"`
- Apply revisions: `./fastapi-migrate`
- Database shell: `./psql`

Keep application code in `src/` and commit Alembic revisions from
`src/alembic/versions/`. Do not commit `.env` or production secrets. For Docker
Compose production read `PROD/README.md`; for Kubernetes/GHCR production read
`PROD/k8s/README.md` and use `./fastapi-prepare-prod --target ghcr-k8s`.
