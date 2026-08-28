#!/usr/bin/env bash
set -euo pipefail

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

helm lint "$chart_dir"

render() {
  local kind="$1"
  shift
  helm template chemistry "$chart_dir" \
    --set "app.kind=$kind" \
    --set app.image.repository=registry.example/chemistry-prod \
    --set "app.image.tag=0.6.2-$kind.1" "$@" >"$scratch_dir/$kind.yaml"
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
! rg -q '^kind: Ingress$' "$scratch_dir/rdkit.yaml"
rg -q '^kind: StatefulSet$' "$scratch_dir/django.yaml"
