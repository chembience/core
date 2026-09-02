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

helm upgrade --install "${APP_NAME:-chembience}" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

For Django migrations, first deploy with `--set migration.enabled=true --wait`.
The migration Job completes before updated Django workers are rolled out; then
run the normal command with migrations disabled. Enable Ingress only after
selecting its controller and TLS configuration.

The bundled RDKit PostgreSQL is one persistent StatefulSet replica. To use an
external RDKit-enabled PostgreSQL database, set `postgres.enabled=false` and
`postgres.host` in `values.override.yaml`.

`chembience` is the documented namespace. `prod` remains the compatible value
of `CHEMBIENCE_RUNTIME_MODE` inside immutable containers.
