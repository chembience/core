# Django App: Guide for AI Agents

This is a generated Chembience Django application, not the Chembience core
repository. Work from this directory; `docker-compose.yml` is authoritative for
development and application code lives in `src/`.

## Development

- Start the stack with `docker compose up -d`.
- Run setup with `./django-init`.
- Run Django commands with `./django-manage-py <command>`.
- Run tests with `./django-manage-py test` (the bundled
  `django_rdkit_test_app` smoke-tests RDKit in Django).
- When models change, create, review, and commit migrations with
  `./django-manage-py makemigrations` and `./django-manage-py migrate`.
- Keep `.env`, `.env.prod`, `PROD/.env`, and generated values files out of Git.

## Production

- Use `./django-configure --prod` to prepare separate production settings.
- `./django-prepare-prod --target compose` prepares the self-hosted Docker
  Compose bundle in `PROD/`; read `PROD/README.md` for that route.
- `./django-prepare-prod --target ghcr-k8s` prepares a Docker-free Kubernetes
  deployment. Its first run creates GitHub Actions configuration; commit and
  push it, wait for the image build, then rerun from the clean commit.
- Read `PROD/k8s/README.md` before deploying to Kubernetes. Keep its
  `values.override.yaml` and Kubernetes Secrets on the deployment host.

## Files managed by Chembience

- `./django-configure`, `./django-prepare-prod`, the other shipped helper
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
  prompts of `./django-configure --prod`.
- Pushing images, or deploying with `helm` or `kubectl` to a real cluster.

Use LF line endings. Do not remove `src/django_rdkit_test_app`; it is an
intentional RDKit integration smoke test.
