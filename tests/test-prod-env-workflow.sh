#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >> "${DOCKER_LOG:?}"' 'exit 0' > "$scratch_dir/bin/docker"
chmod +x "$scratch_dir/bin/docker"
export DOCKER_LOG="$scratch_dir/docker.log"
: > "$DOCKER_LOG"

write_env() {
  local path="$1" app_name="$2"
  cat > "$path" <<EOF
APP_NAME=$app_name
CHEMBIENCE_VERSION=9.9.9
POSTGRES_HOST=external-postgres
POSTGRES_PASSWORD=test-password
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@example.org
DJANGO_SUPERUSER_PASSWORD=strong-test-password
EOF
}

for app in django fastapi jupyter rdkit; do
  app_dir="$scratch_dir/$app"
  mkdir -p "$app_dir"
  cp "$root_dir/$app/app/$app-configure" "$app_dir/configure"
  write_env "$app_dir/.env" "${app}-development"

  (cd "$app_dir" && bash ./configure --prod >/dev/null)
  cmp "$app_dir/.env" "$app_dir/.env.prod"

  write_env "$app_dir/.env" "${app}-updated"
  (cd "$app_dir" && printf 'n\n' | bash ./configure --prod >/dev/null)
  rg -q "APP_NAME=${app}-development" "$app_dir/.env.prod"
  (cd "$app_dir" && printf 'y\n' | bash ./configure --prod >/dev/null)
  rg -q "APP_NAME=${app}-updated" "$app_dir/.env.prod"
  ! (cd "$app_dir" && bash ./configure --prod --rebuild >/dev/null 2>&1)

  cp "$root_dir/$app/app/$app-prepare-prod" "$app_dir/prepare"
  (cd "$app_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build >/dev/null)
  rg -q "APP_NAME=${app}-updated" "$app_dir/PROD/.env"
  test -f "$app_dir/.env.prod"

  write_env "$app_dir/PROD/.env" "${app}-kept"
  (cd "$app_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build --keep-env-prod >/dev/null)
  rg -q "APP_NAME=${app}-kept" "$app_dir/PROD/.env"

  fallback_dir="$scratch_dir/${app}-fallback"
  mkdir -p "$fallback_dir"
  cp "$root_dir/$app/app/$app-prepare-prod" "$fallback_dir/prepare"
  write_env "$fallback_dir/.env" "${app}-fallback"
  (cd "$fallback_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build >/dev/null)
  rg -q "APP_NAME=${app}-fallback" "$fallback_dir/PROD/.env"

  ghcr_dir="$scratch_dir/${app}-ghcr"
  mkdir -p "$ghcr_dir/PROD/k8s"
  cp "$root_dir/$app/app/$app-prepare-prod" "$ghcr_dir/prepare"
  cp "$root_dir/$app/app/k8s/README.md" "$ghcr_dir/PROD/k8s/README.md"
  write_env "$ghcr_dir/.env" "${app}-ghcr"
  printf '%s\n' 'PROD/.env' > "$ghcr_dir/.gitignore"
  git -C "$ghcr_dir" init -q
  git -C "$ghcr_dir" config core.autocrlf false
  git -C "$ghcr_dir" config core.eol lf
  git -C "$ghcr_dir" config user.email 'test@example.org'
  git -C "$ghcr_dir" config user.name 'Chembience test'
  git -C "$ghcr_dir" add .
  git -C "$ghcr_dir" commit -qm 'Initial application'
  git -C "$ghcr_dir" remote add origin "https://github.com/Chembience-Test/${app}-example.git"

  : > "$DOCKER_LOG"
  (cd "$ghcr_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --target ghcr-k8s >/dev/null)
  test -f "$ghcr_dir/chembience-ghcr.env"
  test -f "$ghcr_dir/.github/workflows/chembience-ghcr.yml"
  rg -q "CHEMBIENCE_CORE_IMAGE=chembience/core-${app}:9.9.9" "$ghcr_dir/chembience-ghcr.env"
  rg -q 'docker buildx build --platform linux/amd64' "$ghcr_dir/.github/workflows/chembience-ghcr.yml"
  rg -q 'PROD/k8s/values.generated.yaml' "$ghcr_dir/.gitignore"
  rg -q "helm upgrade --install \"${app}-ghcr\"" "$ghcr_dir/PROD/k8s/README.md"
  ! rg -q 'YOUR_APP_NAME' "$ghcr_dir/PROD/k8s/README.md"
  test ! -s "$DOCKER_LOG"

  git -C "$ghcr_dir" add .
  git -C "$ghcr_dir" commit -qm 'Configure GHCR publishing'
  expected_sha="$(git -C "$ghcr_dir" rev-parse HEAD)"
  : > "$DOCKER_LOG"
  (cd "$ghcr_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --target ghcr-k8s >/dev/null)
  rg -q "repository: \"ghcr.io/chembience-test/${app}-example\"" "$ghcr_dir/PROD/k8s/values.generated.yaml"
  rg -q "tag: \"${expected_sha}\"" "$ghcr_dir/PROD/k8s/values.generated.yaml"
  rg -q 'name: ghcr-pull-secret' "$ghcr_dir/PROD/k8s/values.generated.yaml"
  test ! -s "$DOCKER_LOG"
  test -z "$(git -C "$ghcr_dir" status --porcelain)"

  touch "$ghcr_dir/dirty-file"
  ! (cd "$ghcr_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --target ghcr-k8s >/dev/null 2>&1)
  rm "$ghcr_dir/dirty-file"
  ! (cd "$ghcr_dir" && bash ./prepare --target invalid-target >/dev/null 2>&1)
done

echo "Production environment workflow validated for all app types."
