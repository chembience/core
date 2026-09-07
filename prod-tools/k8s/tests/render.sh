#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
base_dir="$repo_dir/prod-tools/k8s/chart-base"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

assemble() {
  local app="$1"
  local chart_dir="$scratch_dir/$app"
  mkdir -p "$chart_dir"
  cp -a "$base_dir/." "$chart_dir/"
  cp -a "$repo_dir/$app/app/k8s/." "$chart_dir/"
  printf '%s' "$chart_dir"
}

render() {
  local app="$1"
  shift
  local chart_dir
  chart_dir="$(assemble "$app")"
  helm lint "$chart_dir"
  helm template chemistry "$chart_dir" \
    --set app.image.repository=registry.example/chemistry-prod \
    --set "app.image.tag=0.6.2-$app.1" "$@" >"$scratch_dir/$app.yaml"
}

render django
render fastapi --set migration.enabled=true
render jupyter --set ingress.enabled=true --set ingress.host=notebooks.example.org
render rdkit

python3 - "$scratch_dir" <<'PY'
import pathlib
import sys

import yaml

for path in pathlib.Path(sys.argv[1]).glob("*.yaml"):
    list(yaml.safe_load_all(path.read_text()))
PY

rg -q '^kind: Job$' "$scratch_dir/fastapi.yaml"
rg -q '^kind: Ingress$' "$scratch_dir/jupyter.yaml"
! rg -q '^kind: Service$' "$scratch_dir/rdkit.yaml"
rg -q '^kind: StatefulSet$' "$scratch_dir/django.yaml"
! rg -q 'app.kind' "$scratch_dir"/*.yaml
