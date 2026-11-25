#!/usr/bin/env bash
# Prove that a change to the *-prepare-prod scripts or prod-tools/lib/ is
# behavior-preserving.
#
#   tests/compare-prepare-prod.sh [<git-rev>]     (default: HEAD)
#
# Runs every app's *-prepare-prod from <git-rev> and from the working tree
# through the same scenarios with a fake `docker`, and compares stdout, stderr,
# docker invocations, exit codes, and every generated file. Commit SHAs of the
# throwaway GHCR test repositories are masked, because they depend on the
# script content. Exits 0 when both trees behave identically, 1 otherwise
# (the diff is printed). Intentional behavior changes are expected to differ.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rev="${1:-HEAD}"
[[ $# -le 1 && "$rev" != -* ]] || { echo "Usage: $0 [<git-rev>]" >&2; exit 2; }
git -C "$root_dir" rev-parse --verify --quiet "${rev}^{commit}" >/dev/null \
  || { echo "Unknown git revision: $rev" >&2; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/base"
cat > "$work/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${DOCKER_LOG:?}"
exit 0
EOF
chmod +x "$work/bin/docker"
export GIT_AUTHOR_DATE='2026-01-01T00:00:00Z' GIT_COMMITTER_DATE='2026-01-01T00:00:00Z'
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

write_env() {  # file app_name postgres_host
  cat > "$1" <<EOF
APP_NAME=$2
CHEMBIENCE_VERSION=9.9.9
POSTGRES_HOST=$3
POSTGRES_PASSWORD=test-password
DJANGO_VIRTUAL_HOSTNAME=localhost,example.org
EOF
}

# Install an app's script, plus the shared library when the tree has one,
# where the development entrypoint would put it.
setup_app() {  # src dir app
  mkdir -p "$2"
  cp "$1/$3/app/$3-prepare-prod" "$2/prepare"
  if [[ -f "$1/prod-tools/lib/prepare-prod.sh" ]]; then
    mkdir -p "$2/PROD/lib"
    cp "$1/prod-tools/lib/prepare-prod.sh" "$2/PROD/lib/prepare-prod.sh"
  fi
}

run_case() {  # out name dir args...
  local out="$1" name="$2" dir="$3"; shift 3
  export DOCKER_LOG="$out/$name.docker"
  : > "$DOCKER_LOG"
  local status=0
  (cd "$dir" && PATH="$work/bin:$PATH" bash ./prepare "$@") \
    > "$out/$name.stdout" 2> "$out/$name.stderr" || status=$?
  echo "exit=$status" >> "$out/$name.stdout"
  # The library itself is excluded: it only exists in the new layout.
  (cd "$dir" && find . -path ./.git -prune -o -path ./PROD/lib -prune -o -type f ! -name prepare -print \
    | sort | while read -r f; do printf '=== %s\n' "$f"; cat "$f"; done) > "$out/$name.files"
}

snapshot() {  # src out
  local src="$1" out="$2" cases app d
  cases="$work/cases-$(basename "$out")"
  mkdir -p "$out"
  for app in django fastapi jupyter rdkit; do
    d="$cases/$app-ext"; setup_app "$src" "$d" "$app"; write_env "$d/.env" "$app-ext" external-postgres
    run_case "$out" "$app-ext-skip" "$d" --skip-build
    run_case "$out" "$app-ext-build" "$d"
    write_env "$d/PROD/.env" "$app-kept" external-postgres
    run_case "$out" "$app-ext-keep" "$d" --skip-build --keep-env-prod

    d="$cases/$app-local"; setup_app "$src" "$d" "$app"; write_env "$d/.env" "$app-local" postgres
    printf 'CHEMBIENCE_VERSION=1.2.3\nAPP_NAME=from-prod\nPOSTGRES_HOST=postgres\n' > "$d/.env.prod"
    run_case "$out" "$app-local-build" "$d" --image-name registry.example/x --image-tag t1

    d="$cases/$app-legacy"; setup_app "$src" "$d" "$app"; write_env "$d/.env" "$app-legacy" external-postgres
    mkdir -p "$d/prod"; echo legacy > "$d/prod/marker"
    if [[ -d "$d/PROD/lib" ]]; then mv "$d/PROD/lib" "$d/prod/lib"; rmdir "$d/PROD"; fi
    run_case "$out" "$app-legacy" "$d" --skip-build

    d="$cases/$app-ghcr"; setup_app "$src" "$d" "$app"; write_env "$d/.env" "$app-ghcr" external-postgres
    mkdir -p "$d/PROD/k8s"; cp "$src/$app/app/k8s/README.md" "$d/PROD/k8s/README.md"
    printf '%s\n' 'PROD/.env' > "$d/.gitignore"
    git -C "$d" init -q
    git -C "$d" config core.autocrlf false
    git -C "$d" config user.email test@example.org
    git -C "$d" config user.name 'Chembience test'
    git -C "$d" add .; git -C "$d" commit -qm init
    git -C "$d" remote add origin "https://github.com/Chembience-Test/$app-example.git"
    run_case "$out" "$app-ghcr-1" "$d" --target ghcr-k8s
    git -C "$d" add .; git -C "$d" commit -qm ghcr
    run_case "$out" "$app-ghcr-2" "$d" --target ghcr-k8s
    run_case "$out" "$app-bad-target" "$d" --target nope
    run_case "$out" "$app-bad-opt" "$d" --frobnicate
  done
  # Mask commit SHAs of the GHCR test repositories.
  sed -i -E 's/\b[0-9a-f]{40}\b/<SHA>/g' "$out"/*
}

git -C "$root_dir" archive "$rev" | tar -x -C "$work/base"
snapshot "$work/base" "$work/before"
snapshot "$root_dir" "$work/after"

if diff -r "$work/before" "$work/after"; then
  echo "✅ prepare-prod behavior is identical to ${rev} ($(find "$work/after" -type f | wc -l) snapshot files)."
else
  echo "❌ prepare-prod behavior differs from ${rev} (see diff above)." >&2
  exit 1
fi
