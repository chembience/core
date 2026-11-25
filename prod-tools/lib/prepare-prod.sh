# shellcheck shell=bash
# Shared implementation of the <app>-prepare-prod commands.
#
# Generated apps receive this file as PROD/lib/prepare-prod.sh (or prod/lib/ for
# an app that still has a legacy prod/ directory); the development entrypoint
# refreshes it together with the *-prepare-prod script, so both always come
# from the same image version. Sourcing it only defines functions.
#
# An app script sets these variables, may override the hooks below, and then
# calls `prepare_prod_main "$@"`:
#   APP_DIR                      generated app root (the script's directory)
#   PREPARE_PROD_APP             django | fastapi | jupyter | rdkit
#   PREPARE_PROD_DISPLAY_NAME    human-readable name used in messages
#   PREPARE_PROD_PORT_VAR        optional published-port variable, offset by
#   PREPARE_PROD_PORT_DEFAULT      +1000 in PROD/.env so dev and prod can coexist
#   PREPARE_PROD_HAS_MIGRATIONS  1 if the app owns database migrations

# --- .env helpers ------------------------------------------------------------

set_env_var() {
  local file="$1" key="$2" val="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  else
    echo "${key}=${val}" >> "$file"
  fi
}

get_env_var() {
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" | tail -n1 | cut -d= -f2- || true
}

# --- Hooks (override in the app script after sourcing this file) -------------

# Extra PROD/.env adjustments, run after the port offset (e.g. Django CSRF).
prepare_prod_configure_env() { :; }

# Verify the freshly built image "${IMAGE_NAME}:${IMAGE_TAG}".
prepare_prod_verify_image() {
  echo "prepare_prod_verify_image is not defined for ${PREPARE_PROD_APP}" >&2
  return 1
}

# Initialize the bundled database. Runs in PROD/ with postgres started; return
# non-zero on failure (the stack is then stopped and preparation aborts).
prepare_prod_init_database() { prepare_prod_wait_for_postgres; }

# Wait up to ~30s for the bundled postgres service to accept connections.
prepare_prod_wait_for_postgres() {
  # shellcheck disable=SC2016 # expanded inside the postgres container
  local check='pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_NAME"'
  for _ in {1..30}; do
    docker compose exec -T postgres sh -c "$check" >/dev/null 2>&1 && break
    sleep 1
  done
  docker compose exec -T postgres sh -c "$check" >/dev/null
}

# --- Internal steps -------------------------------------------------------------

_prepare_prod_parse_args() {
  KEEP_ENV_PROD=0
  SKIP_BUILD=0
  IMAGE_TAG=""
  IMAGE_NAME=""
  TARGET="compose"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep-env-prod) KEEP_ENV_PROD=1; shift ;;
      --skip-build) SKIP_BUILD=1; shift ;;
      --target)
        [[ $# -ge 2 ]] || { echo "Missing value for --target" >&2; exit 2; }
        TARGET="$2"
        shift 2
        ;;
      --image-name)
        [[ $# -ge 2 ]] || { echo "Missing value for --image-name" >&2; exit 2; }
        IMAGE_NAME="$2"
        shift 2
        ;;
      --image-tag)
        [[ $# -ge 2 ]] || { echo "Missing value for --image-tag" >&2; exit 2; }
        IMAGE_TAG="$2"
        shift 2
        ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) echo "Unexpected argument: $1" >&2; exit 2 ;;
    esac
  done

  [[ "$TARGET" == "compose" || "$TARGET" == "ghcr-k8s" ]] || {
    echo "--target must be either 'compose' or 'ghcr-k8s'" >&2
    exit 2
  }
}

# Create PROD/ (migrating a legacy prod/) and seed PROD/.env.
_prepare_prod_dir() {
  if [[ ! -f .env ]]; then
    echo "Missing ./.env in $APP_DIR. Aborting." >&2
    exit 1
  fi

  local legacy canonical temp
  legacy="$(find "$APP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'prod' -print -quit)"
  canonical="$(find "$APP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'PROD' -print -quit)"
  if [[ -n "$legacy" && -n "$canonical" ]]; then
    echo "Both prod/ and PROD/ exist. Resolve the production directory manually." >&2
    exit 1
  fi
  if [[ -n "$legacy" ]]; then
    temp="$APP_DIR/.chembience-prod-migrate-$$"
    [[ ! -e "$temp" ]] || { echo "Temporary production migration path already exists: $temp" >&2; exit 1; }
    mv "$legacy" "$temp"
    mv "$temp" "$PROD_DIR"
    echo "ℹ️  Renamed legacy prod/ directory to PROD/."
  fi
  mkdir -p "$PROD_DIR"
  if [[ $KEEP_ENV_PROD -eq 0 ]]; then
    if [[ -f "$PROD_SOURCE_ENV" ]]; then
      cp -f "$PROD_SOURCE_ENV" "$PROD_ENV"
      echo "ℹ️  Copied .env.prod to PROD/.env."
    else
      cp -f .env "$PROD_ENV"
    fi
  fi

  if grep -q '^CHEMBIENCE_RUNTIME_MODE=' "$PROD_ENV"; then
    sed -i 's/^CHEMBIENCE_RUNTIME_MODE=.*/CHEMBIENCE_RUNTIME_MODE=prod/' "$PROD_ENV"
  else
    echo 'CHEMBIENCE_RUNTIME_MODE=prod' >> "$PROD_ENV"
  fi
}

# A production environment must not contend with the development stack for its
# published port. Preserve an explicitly distinct production port.
_prepare_prod_offset_port() {
  [[ -n "${PREPARE_PROD_PORT_VAR:-}" ]] || return 0
  local var="$PREPARE_PROD_PORT_VAR" dev_port prod_port
  dev_port="$(get_env_var .env "$var")"
  dev_port="${dev_port:-$PREPARE_PROD_PORT_DEFAULT}"
  prod_port="$(get_env_var "$PROD_ENV" "$var")"
  [[ "$dev_port" =~ ^[0-9]+$ ]] || { echo "$var must be numeric" >&2; exit 2; }
  if [[ $KEEP_ENV_PROD -eq 0 || -z "$prod_port" || "$prod_port" == "$dev_port" ]]; then
    set_env_var "$PROD_ENV" "$var" "$((dev_port + 1000))"
  fi
}

_prepare_prod_write_ghcr_files() {
  mkdir -p .github/workflows
  cat > chembience-ghcr.env <<EOF
# Checked-in, non-secret build configuration for GitHub Actions.
CHEMBIENCE_CORE_IMAGE=${CORE_IMAGE}
EOF
  cat > .github/workflows/chembience-ghcr.yml <<'EOF'
name: Publish Chembience production image

on:
  push:
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build and publish the immutable production image
        run: |
          set -euo pipefail
          source chembience-ghcr.env
          image="ghcr.io/${GITHUB_REPOSITORY,,}"
          docker buildx build --platform linux/amd64 --file Dockerfile.prod \
            --build-arg "CORE_IMAGE=${CHEMBIENCE_CORE_IMAGE}" \
            --label "org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" \
            --label "org.opencontainers.image.revision=${GITHUB_SHA}" \
            --tag "${image}:${GITHUB_SHA}" --push .
EOF
}

_prepare_prod_ensure_k8s_ignores() {
  [[ -f .gitignore ]] || touch .gitignore
  local ignored_path
  for ignored_path in PROD/k8s/values.generated.yaml PROD/k8s/values.override.yaml; do
    grep -Fxq "$ignored_path" .gitignore || echo "$ignored_path" >> .gitignore
  done
}

_prepare_prod_k8s_readme() {
  K8S_DIR="$PROD_DIR/k8s"
  mkdir -p "$K8S_DIR"
  if [[ -f "$K8S_DIR/README.md" ]]; then
    # shellcheck disable=SC2016 # literal ${APP_NAME:-chembience} placeholder
    sed -i -e "s|YOUR_APP_NAME|${APP_NAME_VALUE}|g" -e 's|${APP_NAME:-chembience}|'"${APP_NAME_VALUE}"'|g' "$K8S_DIR/README.md"
  fi
}

# Resolve IMAGE_NAME/IMAGE_TAG for ghcr-k8s from the GitHub origin and HEAD.
# Exits after writing the GHCR workflow on the first run.
_prepare_prod_resolve_ghcr_image() {
  command -v git >/dev/null || { echo "ghcr-k8s preparation requires git" >&2; exit 1; }
  [[ "$(git rev-parse --show-toplevel 2>/dev/null || true)" == "$APP_DIR" ]] || {
    echo "ghcr-k8s preparation must run from the root of a Git repository" >&2
    exit 1
  }
  _prepare_prod_k8s_readme
  if [[ ! -f chembience-ghcr.env || ! -f .github/workflows/chembience-ghcr.yml ]]; then
    _prepare_prod_write_ghcr_files
    _prepare_prod_ensure_k8s_ignores
    echo "Created GitHub Actions GHCR publishing files. Commit and push them, then rerun this command." >&2
    exit 0
  fi
  _prepare_prod_ensure_k8s_ignores
  [[ -z "$(git status --porcelain)" ]] || {
    echo "ghcr-k8s preparation requires a clean Git working tree" >&2
    exit 1
  }
  local origin repository derived_name sha
  origin="$(git config --get remote.origin.url || true)"
  repository="${origin#git@github.com:}"
  repository="${repository#https://github.com/}"
  repository="${repository#ssh://git@github.com/}"
  repository="${repository%.git}"
  [[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
    echo "ghcr-k8s preparation requires origin to be a GitHub repository" >&2
    exit 1
  }
  derived_name="ghcr.io/$(printf '%s' "$repository" | tr '[:upper:]' '[:lower:]')"
  [[ -z "$IMAGE_NAME" || "$IMAGE_NAME" == "$derived_name" ]] || {
    echo "--image-name must match the GitHub origin: $derived_name" >&2
    exit 2
  }
  sha="$(git rev-parse HEAD)"
  [[ -z "$IMAGE_TAG" || "$IMAGE_TAG" == "$sha" ]] || {
    echo "--image-tag must match the current Git commit: $sha" >&2
    exit 2
  }
  IMAGE_NAME="$derived_name"
  IMAGE_TAG="$sha"
}

# Resolve IMAGE_NAME/IMAGE_TAG for the compose target and make the core image
# available locally.
_prepare_prod_resolve_compose_image() {
  if [[ -z "$IMAGE_TAG" ]]; then
    IMAGE_TAG="$(get_env_var "$PROD_ENV" CHEMBIENCE_VERSION)"
  fi
  if [[ -z "$IMAGE_TAG" ]]; then
    IMAGE_TAG="prod-$(date +%Y%m%d%H%M%S)"
  fi
  if [[ -z "$IMAGE_NAME" ]]; then
    IMAGE_NAME="chembience/${APP_NAME_VALUE}-prod"
  fi
  if docker image inspect "${CORE_IMAGE}" >/dev/null 2>&1; then
    echo "📦 Using locally available core image: ${CORE_IMAGE}"
  else
    echo "📥 Pulling required core image: ${CORE_IMAGE}..."
    docker pull "${CORE_IMAGE}"
  fi
}

_prepare_prod_write_values() {
  _prepare_prod_k8s_readme
  cat > "$K8S_DIR/values.generated.yaml" <<EOF
# Generated by ${PREPARE_PROD_APP}-prepare-prod. Do not edit; use values.override.yaml.
app:
  image:
    repository: "${IMAGE_NAME}"
    tag: "${IMAGE_TAG}"
postgres:
  image:
    repository: "chembience/core-rdkit-postgres"
    tag: "${CORE_IMAGE_TAG}"
EOF
}

_prepare_prod_build_image() {
  if [[ $SKIP_BUILD -eq 0 ]]; then
    echo "📦 Building source-baked ${PREPARE_PROD_DISPLAY_NAME} production image ${IMAGE_NAME}:${IMAGE_TAG}..."
    docker build \
      --file ./Dockerfile.prod \
      --build-arg "CORE_IMAGE=${CORE_IMAGE}" \
      --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
      .
    prepare_prod_verify_image
  else
    echo "ℹ️  Skipping build and in-image verification (--skip-build)."
  fi
}

_prepare_prod_init_bundled_database() {
  local postgres_host
  postgres_host="$(get_env_var "$PROD_ENV" POSTGRES_HOST)"
  if [[ "${postgres_host:-postgres}" == "postgres" ]]; then
    echo "🚀 Initializing the self-hosted production database..."
    (
      cd "$PROD_DIR" || exit 1
      docker compose down
      docker compose up -d postgres
      if ! prepare_prod_init_database; then
        docker compose down
        exit 1
      fi
      docker compose down
    )
  elif [[ "${PREPARE_PROD_HAS_MIGRATIONS:-0}" == 1 ]]; then
    echo "ℹ️  External PostgreSQL configured; its migration lifecycle is managed by the database operator."
  else
    echo "ℹ️  External PostgreSQL configured; its lifecycle is managed by the database operator."
  fi
}

# --- Entry point ---------------------------------------------------------------

prepare_prod_main() {
  : "${APP_DIR:?}" "${PREPARE_PROD_APP:?}" "${PREPARE_PROD_DISPLAY_NAME:?}"
  cd "$APP_DIR" || exit 1
  PROD_DIR="$APP_DIR/PROD"
  PROD_ENV="$PROD_DIR/.env"
  PROD_SOURCE_ENV="$APP_DIR/.env.prod"

  _prepare_prod_parse_args "$@"
  _prepare_prod_dir
  _prepare_prod_offset_port
  prepare_prod_configure_env

  APP_NAME_VALUE="$(get_env_var .env APP_NAME)"
  APP_NAME_VALUE="${APP_NAME_VALUE:-$(basename "$APP_DIR")}"
  [[ "$APP_NAME_VALUE" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { echo "APP_NAME must be a valid lowercase Docker image name" >&2; exit 2; }

  CORE_IMAGE_TAG="$(get_env_var .env CHEMBIENCE_VERSION)"
  CORE_IMAGE_TAG="${CORE_IMAGE_TAG:-latest}"
  CORE_IMAGE="chembience/core-${PREPARE_PROD_APP}:${CORE_IMAGE_TAG}"

  if [[ "$TARGET" == "ghcr-k8s" ]]; then
    _prepare_prod_resolve_ghcr_image
  else
    _prepare_prod_resolve_compose_image
  fi

  local project_name
  project_name="$(printf '%s' "$APP_NAME_VALUE" | tr '[:upper:]' '[:lower:]' | tr '.' '-')-prod"
  [[ "$project_name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "APP_NAME must form a valid Compose project name: $APP_NAME_VALUE" >&2; exit 2; }
  set_env_var "$PROD_ENV" CHEMBIENCE_VERSION "$IMAGE_TAG"
  set_env_var "$PROD_ENV" CHEMBIENCE_IMAGE_TAG "$IMAGE_TAG"
  set_env_var "$PROD_ENV" CHEMBIENCE_PROD_IMAGE_NAME "$IMAGE_NAME"
  set_env_var "$PROD_ENV" CHEMBIENCE_POSTGRES_IMAGE "chembience/core-rdkit-postgres:${CORE_IMAGE_TAG}"
  set_env_var "$PROD_ENV" COMPOSE_PROJECT_NAME "$project_name"

  _prepare_prod_write_values

  if [[ "$TARGET" == "ghcr-k8s" ]]; then
    cat >> "$K8S_DIR/values.generated.yaml" <<'EOF'
imagePullSecrets:
  - name: ghcr-pull-secret
EOF
    echo "✅ ${PREPARE_PROD_APP}-prepare-prod created a GHCR-backed Kubernetes bundle."
    echo "ℹ️  Deploy ${IMAGE_NAME}:${IMAGE_TAG} only after the matching GitHub Action succeeds."
    exit 0
  fi

  _prepare_prod_build_image
  _prepare_prod_init_bundled_database

  echo "✅ ${PREPARE_PROD_APP}-prepare-prod completed."
  echo "ℹ️  Created image: ${IMAGE_NAME}:${IMAGE_TAG}"
  echo "ℹ️  Dev environment was not changed; the prepared production stack is stopped."
}
