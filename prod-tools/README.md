# Chembience Production Bundle

This directory is the self-hosted production runtime for this application.
It uses the immutable application image and configuration prepared from the
development workspace.

Start or inspect the prepared stack:

```bash
docker compose up -d
docker compose ps
docker compose logs -f
```

The self-hosted PostgreSQL data remains in Docker's named volume. To move or
recover it, use `./db-backup` and `./db-restore`; moving this directory alone
does not move database data or application images to another Docker host.

Available self-hosted database tools:

```bash
./psql
./db-backup
./db-restore backups/<file>.sql
./db-cleanup
```

For an externally managed PostgreSQL database, use `compose.external.yaml` and
let its operator manage backups, connectivity, and migrations.
