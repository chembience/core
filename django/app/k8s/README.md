# Django Kubernetes production bundle

This self-contained Helm bundle deploys the generated Django application and
its optional bundled RDKit PostgreSQL database. Run `django-prepare-prod`
before deploying; it writes the immutable image references to
`values.generated.yaml`. Do not edit that generated file.

## Private GitHub Container Registry (GHCR)

The default `django-prepare-prod --target compose` builds locally with Docker.
For a Kubernetes host without Docker, use `django-prepare-prod --target ghcr-k8s`
from the root of a generated app that is a Git repository with a GitHub
`origin`. On its first run it writes `chembience-ghcr.env` and
`.github/workflows/chembience-ghcr.yml`, then stops. Commit and push those files.
GitHub Actions publishes the private image tagged with that commit's full SHA.
After the action succeeds, return to the same clean checkout and run the command
again; it writes `values.generated.yaml` with the exact published image.

Before Helm can pull the private image, create a **classic** GitHub personal
access token with only the `read:packages` scope and create this Secret. Do not
put that token in Git:

```bash
kubectl -n chembience create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_READ_PACKAGES_TOKEN
```

The `ghcr-k8s` generated values file references this Secret automatically.

## Deploying on a Kubernetes-only host

Once the GitHub Action for the current commit has succeeded, run
`django-prepare-prod --target ghcr-k8s` again on the development machine. It
writes a SHA-pinned `values.generated.yaml`. Copy only this Kubernetes bundle to
the deployment host; do not copy the Django source tree and do not install
Docker there:

```bash
rsync -av --exclude values.override.yaml PROD/k8s/ \
  YOUR_USER_ACCOUNT@k8s-host.example:~/YOUR_APP_NAME-k8s/
```

On the Kubernetes host, create `values.override.yaml` from its example and
create the GHCR pull Secret above and the Django `chembience-secrets` Secret.
Then use the Helm command below from `~/YOUR_APP_NAME-k8s/`. The host needs only
`kubectl` and Helm; it pulls the immutable application image directly from GHCR.

Create a user-owned override file:

```bash
cp values.override.yaml.example values.override.yaml
```

Adapt `values.override.yaml` for this Django deployment before using Helm—for
example its hostname, Ingress/TLS settings, and external database settings when
applicable.

Create the namespace and required Secret outside Helm:

```bash
kubectl create namespace chembience
kubectl -n chembience create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me' \
  --from-literal=django-secret-key='replace-me'

helm upgrade --install "YOUR_APP_NAME" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

## Django migrations

Run migrations during the first deployment and again only for a release that
contains new Django migration files (normally after a model or schema change).
Do not enable the migration Job for an image-only application release.

For the first deployment, run this command instead of the normal Helm command:

```bash
helm upgrade --install "YOUR_APP_NAME" ./chart \
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
