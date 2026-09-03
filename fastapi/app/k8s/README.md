# FastAPI Kubernetes production bundle

This self-contained Helm bundle deploys the generated FastAPI application and
its optional bundled RDKit PostgreSQL database. Run `fastapi-prepare-prod`
before deploying; it writes the immutable image references to
`values.generated.yaml`. Do not edit that generated file.

Create a user-owned override file:

```bash
cp values.override.yaml.example values.override.yaml
```

Create the namespace and required Secret outside Helm:

```bash
kubectl create namespace chembience
kubectl -n chembience create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me'

helm upgrade --install "{{APP_NAME}}" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

## Database migrations

Run migrations during the first deployment and again only for a release that
contains new Alembic revisions (normally after a database schema change). Do
not enable the migration Job for an image-only API release.

For the first deployment, run this command instead of the normal Helm command:

```bash
helm upgrade --install "{{APP_NAME}}" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml \
  --set migration.enabled=true --wait
```

For a later schema-changing release, use the same command. The Alembic Job runs
before the upgraded API pods start; `--wait` makes Helm wait for it to succeed.
Check a failed Job with `kubectl -n chembience get jobs` and
`kubectl -n chembience logs job/<migration-job-name>`. Do not proceed with the
normal deployment until the migration succeeds.

After a successful migration run, deploy normally (without
`migration.enabled=true`) so migrations remain disabled for subsequent
image-only releases. Enable Ingress only after selecting its controller and TLS
configuration.

The bundled RDKit PostgreSQL is one persistent StatefulSet replica. To use an
external RDKit-enabled PostgreSQL database, set `postgres.enabled=false` and
`postgres.host` in `values.override.yaml`.

`chembience` is the documented namespace. `prod` remains the compatible value
of `CHEMBIENCE_RUNTIME_MODE` inside immutable containers.
