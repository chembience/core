#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$scratch_dir/bin/docker"
chmod +x "$scratch_dir/bin/docker"

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
done

echo "Production environment workflow validated for all app types."
