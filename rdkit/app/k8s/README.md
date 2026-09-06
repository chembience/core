# RDKit Kubernetes production bundle

This self-contained Helm bundle deploys the generated long-running RDKit
workload and its optional bundled RDKit PostgreSQL database. Run
`rdkit-prepare-prod` before deploying; it writes the immutable image references
to `values.generated.yaml`. Do not edit that generated file.

Create the deployment namespace once, before creating any Secrets:

```bash
kubectl create namespace chembience
```

## Private GitHub Container Registry (GHCR)

The default `rdkit-prepare-prod --target compose` builds locally with Docker.
For a Kubernetes host without Docker, use `rdkit-prepare-prod --target ghcr-k8s`
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
`rdkit-prepare-prod --target ghcr-k8s` again on the development machine. It
writes a SHA-pinned `values.generated.yaml`. Copy only this Kubernetes bundle to
the deployment host; do not copy the RDKit source tree and do not install Docker
there:

```bash
rsync -av --exclude values.override.yaml PROD/k8s/ \
  YOUR_USER_ACCOUNT@k8s-host.example:~/YOUR_APP_NAME-k8s/
```

On the Kubernetes host, create `values.override.yaml` from its example and
create the GHCR pull Secret above and the RDKit `chembience-secrets` Secret.
Then use the Helm command below from `~/YOUR_APP_NAME-k8s/`. The host needs only
`kubectl` and Helm; it pulls the immutable application image directly from GHCR.

Create a user-owned override file:

```bash
cp values.override.yaml.example values.override.yaml
```

Adapt `values.override.yaml` for this RDKit deployment before using Helm—for
example its external database settings when applicable.

Create the required application Secret outside Helm:

```bash
kubectl -n chembience create secret generic chembience-secrets \
  --from-literal=postgres-password='replace-me'

helm upgrade --install "YOUR_APP_NAME" ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

The RDKit workload has no public Service or Ingress; run scripts with
`kubectl exec` or add a purpose-built worker or API.

The bundled RDKit PostgreSQL is one persistent StatefulSet replica. To use an
external RDKit-enabled PostgreSQL database, set `postgres.enabled=false` and
`postgres.host` in `values.override.yaml`.

`chembience` is the documented namespace. `prod` remains the compatible value
of `CHEMBIENCE_RUNTIME_MODE` inside immutable containers.
