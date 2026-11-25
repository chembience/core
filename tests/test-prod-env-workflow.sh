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

# Install an app's prepare-prod script and the shared library it sources, laid
# out as the development entrypoint does (PROD/lib, or prod/lib when legacy).
install_prepare() {
  local app="$1" dir="$2" lib_dir="${3:-PROD}"
  cp "$root_dir/$app/app/$app-prepare-prod" "$dir/prepare"
  mkdir -p "$dir/$lib_dir/lib"
  cp "$root_dir/prod-tools/lib/prepare-prod.sh" "$dir/$lib_dir/lib/prepare-prod.sh"
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

  install_prepare "$app" "$app_dir"
  (cd "$app_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build >/dev/null)
  rg -q "APP_NAME=${app}-updated" "$app_dir/PROD/.env"
  test -f "$app_dir/.env.prod"

  write_env "$app_dir/PROD/.env" "${app}-kept"
  (cd "$app_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build --keep-env-prod >/dev/null)
  rg -q "APP_NAME=${app}-kept" "$app_dir/PROD/.env"

  fallback_dir="$scratch_dir/${app}-fallback"
  mkdir -p "$fallback_dir"
  install_prepare "$app" "$fallback_dir"
  write_env "$fallback_dir/.env" "${app}-fallback"
  (cd "$fallback_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build >/dev/null)
  rg -q "APP_NAME=${app}-fallback" "$fallback_dir/PROD/.env"

  ghcr_dir="$scratch_dir/${app}-ghcr"
  mkdir -p "$ghcr_dir/PROD/k8s"
  install_prepare "$app" "$ghcr_dir"
  cp "$root_dir/$app/app/k8s/README.md" "$ghcr_dir/PROD/k8s/README.md"
  write_env "$ghcr_dir/.env" "${app}-ghcr"
  git -C "$ghcr_dir" init -q
  git -C "$ghcr_dir" config core.autocrlf false
  git -C "$ghcr_dir" config core.eol lf
  git -C "$ghcr_dir" config user.email 'test@example.org'
  git -C "$ghcr_dir" config user.name 'Chembience test'
  cp "$root_dir/.gitignore" "$ghcr_dir/.gitignore"
  printf '%s\n' 'PROD/.env' >> "$ghcr_dir/.gitignore"
  git -C "$ghcr_dir" add .
  git -C "$ghcr_dir" commit -qm 'Initial application'
  # The shipped .gitignore ignores Python lib/ dirs but must keep PROD/lib.
  git -C "$ghcr_dir" ls-files --error-unmatch PROD/lib/prepare-prod.sh >/dev/null
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

  # A legacy prod/ directory carries the library; it is migrated to PROD/.
  legacy_dir="$scratch_dir/${app}-legacy"
  mkdir -p "$legacy_dir/prod"
  install_prepare "$app" "$legacy_dir" prod
  write_env "$legacy_dir/.env" "${app}-legacy"
  (cd "$legacy_dir" && PATH="$scratch_dir/bin:$PATH" bash ./prepare --skip-build >/dev/null)
  test ! -e "$legacy_dir/prod"
  test -f "$legacy_dir/PROD/lib/prepare-prod.sh"
  rg -q "APP_NAME=${app}-legacy" "$legacy_dir/PROD/.env"

  # Without the library the script fails with a hint instead of a bash error.
  missing_dir="$scratch_dir/${app}-missing-lib"
  mkdir -p "$missing_dir"
  cp "$root_dir/$app/app/$app-prepare-prod" "$missing_dir/prepare"
  write_env "$missing_dir/.env" "${app}-missing"
  ! (cd "$missing_dir" && bash ./prepare --skip-build >/dev/null 2>"$scratch_dir/missing.err")
  rg -q 'Missing PROD/lib/prepare-prod.sh' "$scratch_dir/missing.err"
done

echo "Production environment workflow validated for all app types."
