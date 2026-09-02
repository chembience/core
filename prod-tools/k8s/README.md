# Kubernetes production bundle

This directory is the Helm deployment bundle for this generated Chembience
application. It is self-contained: it does not require a checkout of the
Chembience core repository.

Run the matching `*-prepare-prod` helper before deploying. It creates
`values.generated.yaml` with the immutable application image and matching RDKit
PostgreSQL image. Do not edit that file; preparation replaces it.

Copy the example to a user-owned override file and set public configuration:

```bash
cp values.override.yaml.example values.override.yaml
```

Create the namespace and Secret outside Helm. At minimum the Secret must
contain `postgres-password`; Django also requires `django-secret-key`, and
Jupyter requires `jupyter-token`.

```bash
kubectl create namespace production
kubectl -n production create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me'

helm upgrade --install "${APP_NAME:-chembience}" ./chart \
  --namespace production --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

For Django and FastAPI schema changes, first deploy with
`--set migration.enabled=true --wait`. The migration Job is a pre-upgrade hook;
then run the normal command above with migrations disabled. On first install it
is a post-install hook, so leave Ingress disabled until it completes.

The bundled RDKit PostgreSQL is one StatefulSet replica backed by one PVC. It
is persistent but not highly available; use your platform's backup process and
test restores. To use an external RDKit-enabled PostgreSQL database, set
`postgres.enabled=false` and `postgres.host` in `values.override.yaml`.

`production` is the environment/namespace name. `prod` remains the compatible
value of `CHEMBIENCE_RUNTIME_MODE` inside immutable Chembience containers.
