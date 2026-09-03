# Django Kubernetes production bundle

This self-contained Helm bundle deploys the generated Django application and
its optional bundled RDKit PostgreSQL database. Run `django-prepare-prod`
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
  --from-literal=postgres-password='replace-me' \
  --from-literal=django-secret-key='replace-me'

helm upgrade --install "{{APP_NAME}}" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

## Django migrations

Run migrations during the first deployment and again only for a release that
contains new Django migration files (normally after a model or schema change).
Do not enable the migration Job for an image-only application release.

For the first deployment, run this command instead of the normal Helm command:

```bash
helm upgrade --install "{{APP_NAME}}" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml \
  --set migration.enabled=true --wait
```

For a later schema-changing release, use the same command. The Job runs before
the upgraded Django workers start; `--wait` makes Helm wait for it to succeed.
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
