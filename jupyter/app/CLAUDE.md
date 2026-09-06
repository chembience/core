# JupyterLab App Development Guide

Run commands from this generated app directory.

- Start: `docker compose up -d`
- Validate and print the access URL: `./jupyter-init`
- Database shell: `./psql`
- Add notebook/script dependencies to `app-requirements.txt`

Keep notebooks and supporting code in `notebooks/`. Do not commit `.env` or the
Jupyter token. For Docker Compose production read `PROD/README.md`; for
Kubernetes/GHCR production read `PROD/k8s/README.md` and use
`./jupyter-prepare-prod --target ghcr-k8s`.
