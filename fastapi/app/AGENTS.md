# FastAPI App Context Guidance

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

Use LF line endings and never bake secrets into an image.
