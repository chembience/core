# JupyterLab App Context Guidance

This is a generated Chembience JupyterLab application, not the Chembience core
repository. Work from this directory; notebooks and supporting code live in
`notebooks/`.

## Development

- Start the stack with `docker compose up -d`, then run `./jupyter-init` to
  validate it and print the token-protected access URL.
- Add notebook/script dependencies to `app-requirements.txt`.
- Use `./psql` for the bundled PostgreSQL database.
- Keep `.env`, `.env.prod`, `PROD/.env`, and generated values files out of Git.
- Keep `JUPYTER_TOKEN` enabled outside local development and treat it as a
  secret.

## Production

- Use `./jupyter-configure --prod` to prepare separate production settings.
- `./jupyter-prepare-prod --target compose` prepares the self-hosted Docker
  Compose bundle in `PROD/`; read `PROD/README.md` for that route.
- `./jupyter-prepare-prod --target ghcr-k8s` prepares a Docker-free Kubernetes
  deployment. Its first run creates GitHub Actions configuration; commit and
  push it, wait for the image build, then rerun from the clean commit.
- Read `PROD/k8s/README.md` before deploying to Kubernetes, especially for the
  pull Secret, Jupyter token Secret, Ingress, and TLS.

Use LF line endings and never bake tokens or other secrets into an image.
