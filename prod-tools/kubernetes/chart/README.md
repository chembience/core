# Chembience Helm chart

This chart deploys one frozen Chembience application image (`django`, `fastapi`,
`jupyter`, or `rdkit`) and, by default, a single-node RDKit PostgreSQL instance.
It is the Kubernetes alternative to a generated application's self-hosted
`PROD/` Compose bundle; it does not replace that bundle. In a generated app,
run the commands below from `PROD/kubernetes/`, where this chart is `./chart`.

## Install

Build and publish a generated application's immutable `-prod` image first.
Create its namespace and a Secret outside Helm; never commit these values:

```bash
kubectl create namespace production
kubectl -n production create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me' \
  --from-literal=django-secret-key='replace-me' \
  --from-literal=jupyter-token='replace-me'

helm upgrade --install chemistry ./chart \
  --namespace production \
  --set app.kind=django \
  --set app.image.repository=registry.example/chemistry-prod \
  --set app.image.tag=0.6.2-django.1 \
  --set django.virtualHostname=chem.example.org \
  --set django.csrfTrustedOrigins=https://chem.example.org
```

`production` is the canonical human-facing environment name. The chart keeps
`CHEMBIENCE_RUNTIME_MODE=prod` because it is the existing immutable-runtime API
and image naming convention. Do not use misspelled alternatives such as
`prodction`.

## Migrations and releases

For Django and FastAPI, run a migration release separately and wait for it.
On upgrade the Job is a Helm `pre-upgrade` hook, so it completes before the
Deployment receives the new image. On first install it is a `post-install` hook;
keep Ingress disabled until that first migration completes.

```bash
helm upgrade --install chemistry ./chart -n production \
  -f values.generated.yaml -f values.override.yaml \
  --set migration.enabled=true --wait
kubectl -n production wait --for=condition=complete job \
  -l app.kubernetes.io/component=migration --timeout=10m
helm upgrade chemistry ./chart -n production \
  -f values.generated.yaml -f values.override.yaml \
  --set migration.enabled=false
```

The migration Job name includes the application image tag, allowing a new Job
for every immutable release. The default TTL cleans completed Jobs after one
day. Use backward-compatible migrations because the prior Deployment can run
until the final rollout.

## Database and operations

The bundled database is one StatefulSet replica and one read-write-once PVC. It
is persistent, but it is not highly available and no backup CronJob is created.
Back up with a scheduled external operator or a Kubernetes CronJob that runs
`pg_dump` against the `*-postgres` Service; test restores before relying on it.

The current images start as root for their entrypoint's user/ownership setup;
PostgreSQL then drops to the application user after initializing its mounted
volume. Clusters with a non-root-only admission policy need an approved
exception or hardened future images.

Set `postgres.enabled=false` and `postgres.host` to use an externally managed,
RDKit-enabled PostgreSQL database.

## Ingress

Set `ingress.enabled=true`, `ingress.host`, and optionally
`ingress.className`/TLS values for Django, FastAPI, or Jupyter. The cluster must
already provide an Ingress controller. The chart intentionally does not select
an ingress controller or certificate manager.
