# Django App Development Guide

Run commands from this generated app directory.

- Start: `docker compose up -d`
- Initialize/test: `./django-init`
- Management commands: `./django-manage-py <command>`
- Migrations: `./django-manage-py makemigrations` then
  `./django-manage-py migrate`
- Database shell: `./psql`

Application code and Django migrations belong in `src/`. Do not commit `.env`
or production secrets. For Docker Compose production read `PROD/README.md`; for
Kubernetes/GHCR production read `PROD/k8s/README.md` and use
`./django-prepare-prod --target ghcr-k8s`.
