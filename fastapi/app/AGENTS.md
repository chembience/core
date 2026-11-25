# FastAPI App: Guide for AI Agents

This is a generated Chembience FastAPI application, not the Chembience core
repository. Work from this directory; `docker-compose.yml` is authoritative for
development and the API entry point is `src/main.py`.

## Development

- Start the stack with `docker compose up -d` and initialize it with
  `./fastapi-init`.
- Keep SQLAlchemy models in `src/` and Alembic revisions in
  `src/alembic/versions/`.
- For a schema change, run `./fastapi-makemigrations "description"`, review and
  commit the revision, then run `./fastapi-migrate`.
- Run tests with `docker compose exec fastapi pytest`.
- Keep `.env`, `.env.prod`, `PROD/.env`, and generated values files out of Git.

## Production

- Use `./fastapi-configure --prod` to prepare separate production settings.
- `./fastapi-prepare-prod --target compose` prepares the self-hosted Docker
  Compose bundle in `PROD/`; read `PROD/README.md` for that route.
- `./fastapi-prepare-prod --target ghcr-k8s` prepares a Docker-free Kubernetes
  deployment. Its first run creates GitHub Actions configuration; commit and
  push it, wait for the image build, then rerun from the clean commit.
- Read `PROD/k8s/README.md` before deploying to Kubernetes. Run the migration
  Helm release only when the image contains a new Alembic revision.

## Files managed by Chembience

- `./fastapi-configure`, `./fastapi-prepare-prod`, the other shipped helper
  scripts, `PROD/db-*`, and `PROD/lib/prepare-prod.sh` are refreshed from the
  core image on every development `docker compose up`; local edits are
  overwritten. Change behavior through `.env`, and commit `PROD/lib/` (the
  `ghcr-k8s` route runs from a clean checkout).
- Other copied files (`docker-compose.yml`, `Dockerfile*`, `README.md`, this
  file) are only created when missing and are yours to edit.

## Ask the user before

- `docker compose down -v`, `docker volume rm`, or any `db-restore` /
  `db-cleanup` script: they delete or replace database data.
- Editing `.env`, `.env.prod`, or `PROD/.env` secrets, or answering overwrite
  prompts of `./fastapi-configure --prod`.
- Pushing images, or deploying with `helm` or `kubectl` to a real cluster.

Use LF line endings and never bake secrets into an image.
