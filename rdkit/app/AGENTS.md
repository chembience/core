# RDKit App: Guide for AI Agents

This is a generated Chembience RDKit application, not the Chembience core
repository. Work from this directory; place scripts and dependencies here for
the long-running RDKit environment.

## Development

- Start the stack with `docker compose up -d` and verify it with `./rdkit-init`.
- Run scripts with `./run your_script.py` and use `./shell` for an interactive
  Python session.
- Add script dependencies to `requirements.txt`.
- Use `./psql` for the bundled PostgreSQL database.
- Keep `.env`, `.env.prod`, `PROD/.env`, and generated values files out of Git.

## Production

- Use `./rdkit-configure --prod` to prepare separate production settings.
- `./rdkit-prepare-prod --target compose` prepares the self-hosted Docker
  Compose bundle in `PROD/`; read `PROD/README.md` for that route.
- `./rdkit-prepare-prod --target ghcr-k8s` prepares a Docker-free Kubernetes
  deployment. Its first run creates GitHub Actions configuration; commit and
  push it, wait for the image build, then rerun from the clean commit.
- Read `PROD/k8s/README.md` before deploying to Kubernetes. The RDKit workload
  has no public Service or Ingress unless you add a purpose-built worker or API.

## Files managed by Chembience

- `./rdkit-configure`, `./rdkit-prepare-prod`, the other shipped helper
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
  prompts of `./rdkit-configure --prod`.
- Pushing images, or deploying with `helm` or `kubectl` to a real cluster.

Use LF line endings and never bake secrets into an image.
