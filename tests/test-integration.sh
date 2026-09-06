#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHEMBIENCE_VERSION="${CHEMBIENCE_VERSION:-$(tr -d '[:space:]' < "$root_dir/VERSION")}"
scratch_dir="$(mktemp -d)"
copy_dir="$scratch_dir/core"
apps_dir="$scratch_dir/apps"
apps=(django fastapi jupyter rdkit)

for command in docker tar curl sed; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command for integration tests: $command" >&2
    exit 1
  }
done

cleanup() {
  for app in "${apps[@]}"; do
    local_dir="$apps_dir/$app"
    [[ -d "$local_dir/PROD" ]] && (cd "$local_dir/PROD" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
    [[ -d "$local_dir" ]] && (cd "$local_dir" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
  done
  # pytest can leave root-owned cache files through docker compose exec.
  # The core image is already available after the first app build and lets us
  # remove only this mktemp-created directory without requiring host sudo.
  rm -rf "$scratch_dir" 2>/dev/null || {
    docker run --rm --user root --entrypoint /bin/sh \
      -v "$scratch_dir:/scratch" "chembience/core-rdkit:${CHEMBIENCE_VERSION}" \
      -c 'find /scratch -mindepth 1 -maxdepth 1 -exec rm -rf {} +' >/dev/null 2>&1 || true
    rmdir "$scratch_dir" 2>/dev/null || true
  }
}
trap cleanup EXIT

mkdir -p "$copy_dir" "$apps_dir"
tar -C "$root_dir" --exclude=.git --exclude=.env --exclude=test-builds -cf - . \
  | tar -C "$copy_dir" -xf -

cp "$copy_dir/.env.template" "$copy_dir/.env"
sed -i 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=integration-postgres-password-9f4c2b7a/' "$copy_dir/.env"
sed -i 's/^DJANGO_SUPERUSER_PASSWORD=.*/DJANGO_SUPERUSER_PASSWORD=integration-django-password-9f4c2b7a/' "$copy_dir/.env"
# Avoid colliding with a developer's locally running Chembience stack.
sed -i 's/^DJANGO_CONNECTION_PORT=.*/DJANGO_CONNECTION_PORT=18001/' "$copy_dir/.env"
sed -i 's/^FASTAPI_CONNECTION_PORT=.*/FASTAPI_CONNECTION_PORT=18002/' "$copy_dir/.env"
sed -i 's/^JUPYTER_CONNECTION_PORT=.*/JUPYTER_CONNECTION_PORT=18888/' "$copy_dir/.env"

env_value() {
  sed -n "s/^$2=//p" "$1" | tail -n 1
}

wait_http() {
  local url="$1"
  for _ in $(seq 1 30); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' "$url" || true)"
    [[ "$code" =~ ^[23] ]] && return 0
    sleep 2
  done
  echo "Timed out waiting for $url" >&2
  return 1
}

for app in "${apps[@]}"; do
  echo "🧪 Integration testing $app"
  (cd "$copy_dir" && ./build "$app" "$app" -d "$apps_dir" --no-prompt)
  app_dir="$apps_dir/$app"
  test -f "$app_dir/AGENTS.md"
  test -f "$app_dir/CLAUDE.md"
  (cd "$app_dir" && "./$app-init")

  if [[ "$app" == fastapi ]]; then
    (cd "$app_dir" && docker compose exec -T fastapi pytest -q)
  fi

  (cd "$app_dir" && "./$app-configure" --prod)
  sed -i 's/^POSTGRES_HOST=.*/POSTGRES_HOST=postgres/' "$app_dir/.env.prod"
  if [[ "$app" == django ]]; then
    sed -i 's/^DJANGO_SUPERUSER_PASSWORD=.*/DJANGO_SUPERUSER_PASSWORD=integration-django-password-9f4c2b7a/' "$app_dir/.env.prod"
  fi
  (cd "$app_dir" && "./$app-prepare-prod")
  (cd "$app_dir/PROD" && docker compose up -d && docker compose up --wait)

  prod_env="$app_dir/PROD/.env"
  case "$app" in
    django)
      port="$(env_value "$prod_env" DJANGO_CONNECTION_PORT)"
      wait_http "http://localhost:${port}/healthz/"
      (cd "$app_dir/PROD" && docker compose exec -T django python manage.py shell -c "from django.contrib.auth import authenticate; assert authenticate(username='admin', password='integration-django-password-9f4c2b7a')")
      ;;
    fastapi)
      port="$(env_value "$prod_env" FASTAPI_CONNECTION_PORT)"
      wait_http "http://localhost:${port}/healthz"
      (cd "$app_dir/PROD" && docker compose exec -T fastapi alembic -c /home/app/src/alembic.ini check)
      ;;
    jupyter)
      port="$(env_value "$prod_env" JUPYTER_CONNECTION_PORT)"
      wait_http "http://localhost:${port}/api"
      ;;
    rdkit)
      (cd "$app_dir/PROD" && docker compose exec -T rdkit python -c "from rdkit import Chem; assert Chem.MolFromSmiles('c1ccccc1') is not None")
      ;;
  esac
  (cd "$app_dir/PROD" && docker compose down -v --remove-orphans)
  (cd "$app_dir" && docker compose down -v --remove-orphans)
done

echo "✅ Full development and production integration suite passed."
