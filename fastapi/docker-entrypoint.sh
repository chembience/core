#!/bin/bash
set -e
umask 077

CHEMBIENCE_UID="${CHEMBIENCE_UID:-1000}"
CHEMBIENCE_GID="${CHEMBIENCE_GID:-1000}"
CHEMBIENCE_RUNTIME_MODE="$(echo "${CHEMBIENCE_RUNTIME_MODE:-dev}" | tr '[:upper:]' '[:lower:]')"
if [ "${CHEMBIENCE_RUNTIME_MODE}" = "production" ]; then
    CHEMBIENCE_RUNTIME_MODE="prod"
fi

# Pick a group to use:
# - Prefer an existing "app" group
# - Else, if the requested GID already exists, reuse that group's name
# - Else, create "app" with the requested GID
if ! getent group app >/dev/null 2>&1; then
    if getent group "${CHEMBIENCE_GID}" >/dev/null 2>&1; then
        # A group with this GID already exists — reuse its name rather than
        # creating a duplicate; the user 'app' will be bound to it below.
        APP_GROUP="$(getent group "${CHEMBIENCE_GID}" | cut -d: -f1)"
        echo "✅ Group with GID $CHEMBIENCE_GID already exists: $APP_GROUP"
    else
        echo "➕ Creating group 'app' with GID $CHEMBIENCE_GID..."
        groupadd -g "${CHEMBIENCE_GID}" app
        APP_GROUP="app"
    fi
else
    APP_GROUP="app"
    echo "✅ Group 'app' already exists."
fi

if ! id "app" >/dev/null 2>&1; then
    echo "➕ Creating user 'app' with UID $CHEMBIENCE_UID and group $APP_GROUP..."
    useradd --shell /bin/bash -u "${CHEMBIENCE_UID}" -g "${APP_GROUP}" -o -c "" -M app
else
    echo "✅ User 'app' already exists."
fi

id app >/dev/null 2>&1

# Ensure correct ownership and permissions for /home/app.
# Selective chown to avoid a slow full -R sweep on large bind-mounted volumes.
echo "🔧 Ensuring correct ownership of /home/app..."
fix_ownership() {
    if [ "${CHEMBIENCE_RUNTIME_MODE}" = "prod" ]; then
        [ -d /home/app ] && chown app:"$APP_GROUP" /home/app 2>/dev/null || true
        [ -d /home/app/src ] && chown app:"$APP_GROUP" /home/app/src 2>/dev/null || true
        return 0
    fi
    find /home/app -not -user app -print0 2>/dev/null \
        | xargs -0 -r chown "app:$APP_GROUP" 2>/dev/null || true
}
cleanup_ownership() {
    echo "🧹 Finalizing ownership of /home/app..."
    fix_ownership
}
if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ]; then
    trap cleanup_ownership EXIT
fi

fix_ownership

# Helpers ---------------------------------------------------------------------
# sync_config: copy a baked-in config file into APP_HOME only if missing.
# User edits on the bind mount are preserved; a ".dist" copy is always
# refreshed so users can diff against the latest shipped version.
sync_config() {
    src="$1"; dst="$2"
    [ -f "$src" ] || return 0
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        sed -i 's/\r$//' "$dst" 2>/dev/null || true
    fi
#    cp "$src" "${dst}.dist"
#    sed -i 's/\r$//' "${dst}.dist" 2>/dev/null || true
}

# sync_script: always refresh helper scripts, strip CRLF, mark executable.
sync_script() {
    src="$1"; dst="$2"
    [ -f "$src" ] || return 0
    cp "$src" "$dst"
    chmod +x "$dst"
    sed -i 's/\r$//' "$dst"
}

if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ]; then
    echo "📄 Syncing internal configuration files to /home/app..."
    sync_config "/fastapi/docker-compose.yml"          "/home/app/docker-compose.yml"
    sync_config "/fastapi/docker-compose.override.yml" "/home/app/docker-compose.override.yml"
    sync_config "/fastapi/Dockerfile"                  "/home/app/Dockerfile"
    sync_config "/fastapi/Dockerfile.prod"             "/home/app/Dockerfile.prod"
    if [ ! -d "/home/app/prod" ]; then
        mkdir -p "/home/app/PROD"
        sync_config "/fastapi/PROD/compose.yaml"           "/home/app/PROD/compose.yaml"
        sync_config "/fastapi/PROD/compose.external.yaml"  "/home/app/PROD/compose.external.yaml"
        sync_script "/fastapi/prod-tools/psql" "/home/app/PROD/psql"
        sync_script "/fastapi/prod-tools/db-backup" "/home/app/PROD/db-backup"
        sync_script "/fastapi/prod-tools/db-restore" "/home/app/PROD/db-restore"
        sync_script "/fastapi/prod-tools/db-cleanup" "/home/app/PROD/db-cleanup"
        sync_config "/fastapi/prod-tools/README.md" "/home/app/PROD/README.md"
    fi
    mkdir -p "/home/app/PROD/kubernetes"
    if [ ! -d "/home/app/PROD/kubernetes/chart" ]; then
        cp -a "/fastapi/prod-tools/kubernetes/chart" "/home/app/PROD/kubernetes/chart"
    fi
    sync_config "/fastapi/prod-tools/kubernetes/README.md" "/home/app/PROD/kubernetes/README.md"
    sync_config "/fastapi/prod-tools/kubernetes/values.override.yaml.example" "/home/app/PROD/kubernetes/values.override.yaml.example"
    sync_config "/fastapi/requirements.txt"            "/home/app/requirements.txt"
    sync_config "/fastapi/README.md"                   "/home/app/README.md"
    sync_script "/fastapi/psql"                        "/home/app/psql"
    sync_script "/fastapi/db-backup"                   "/home/app/db-backup"
    sync_script "/fastapi/db-restore"                  "/home/app/db-restore"
    sync_script "/fastapi/db-cleanup"                  "/home/app/db-cleanup"
    # fastapi-init is now expected to be in /fastapi/fastapi-init (synced from fastapi/app/fastapi-init in Dockerfile)
    sync_script "/fastapi/fastapi-init"                "/home/app/fastapi-init"
    sync_script "/fastapi/fastapi-migrate"             "/home/app/fastapi-migrate"
    sync_script "/fastapi/fastapi-makemigrations"      "/home/app/fastapi-makemigrations"
    sync_script "/fastapi/fastapi-configure"           "/home/app/fastapi-configure"
    sync_script "/fastapi/fastapi-prepare-prod"        "/home/app/fastapi-prepare-prod"
    [ -f "/.gitignore" ] && [ ! -f "/home/app/.gitignore" ] && cp "/.gitignore" "/home/app/.gitignore"
    [ -f "/.dockerignore" ] && [ ! -f "/home/app/.dockerignore" ] && cp "/.dockerignore" "/home/app/.dockerignore"
    [ -f "/.gitattributes" ] && [ ! -f "/home/app/.gitattributes" ] && cp "/.gitattributes" "/home/app/.gitattributes"
    if [ -f "/home/app/.gitignore" ]; then
        if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.gitignore"; then
            echo "" >> "/home/app/.gitignore"
            echo "# Added by entrypoint" >> "/home/app/.gitignore"
            echo "postgres/postgres_data" >> "/home/app/.gitignore"
        fi
        if ! grep -Eq "^PROD/kubernetes/values\.generated\.yaml([[:space:]]|#|$)" "/home/app/.gitignore"; then
            echo "PROD/kubernetes/values.generated.yaml" >> "/home/app/.gitignore"
            echo "PROD/kubernetes/values.override.yaml" >> "/home/app/.gitignore"
        fi
    fi
    if [ -f "/home/app/.dockerignore" ]; then
        if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.dockerignore"; then
            echo "" >> "/home/app/.dockerignore"
            echo "# Added by entrypoint" >> "/home/app/.dockerignore"
            echo "postgres/postgres_data" >> "/home/app/.dockerignore"
        fi
    fi
fi

# Create/reconcile the per-app .env (source of truth for this app)
ensure_kv() {
    # ensure_kv FILE VAR VALUE  -> append VAR=VALUE if VAR is missing in FILE
    local file="$1" var="$2" val="$3"
    if ! grep -E "^${var}=" "$file" >/dev/null 2>&1; then
        echo "${var}=${val}" >>"$file"
    fi
}

if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ] && [ ! -f "/home/app/.env" ]; then
    echo "📝 Creating minimal .env for FastAPI in /home/app..."
    {
        echo "# ⚠️ AUTO-GENERATED FILE - INITIAL TEMPLATE"
        echo "# Generated by Chembience FastAPI entrypoint"
        echo ""
        echo "CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION:-latest}"
        echo "CHEMBIENCE_IMAGE_TAG=${CHEMBIENCE_VERSION:-latest}"
        echo "APP_NAME=${APP_NAME:-app}"
        echo "APP_HOME=."
        echo "CHEMBIENCE_UID=${CHEMBIENCE_UID}"
        echo "CHEMBIENCE_GID=${CHEMBIENCE_GID}"
        echo "FASTAPI_CONNECTION_PORT=${FASTAPI_CONNECTION_PORT:-8002}"
        echo "POSTGRES_USER=${POSTGRES_USER:-chembience}"
        echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
        echo "POSTGRES_NAME=${POSTGRES_NAME:-chembience}"
        echo "POSTGRES_HOST=${POSTGRES_HOST:-postgres}"
        echo "POSTGRES_PORT=${POSTGRES_PORT:-5432}"
    } > "/home/app/.env"

    # Ensure LF line endings for .env
    sed -i 's/\r$//' "/home/app/.env"
elif [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ]; then
    # Non-destructive reconciliation: ensure critical keys exist
    echo "🔁 Reconciling required keys in existing .env..."
    ensure_kv "/home/app/.env" "FASTAPI_CONNECTION_PORT" "${FASTAPI_CONNECTION_PORT:-8002}"
fi

# Ensure all synced files have correct ownership
fix_ownership

if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ]; then
    # Sync src from the image into the bind-mounted /home/app.
    # The host bind mount (${APP_HOME}:/home/app) shadows the src/ baked into
    # the image, so we must materialize it here on every start. We only copy files
    # that don't already exist in the target so user edits are preserved across
    # restarts, but missing files (e.g. main.py on a freshly created APP_HOME) are
    # always restored — otherwise uvicorn fails with "Could not import module main".
    if [ -d "/fastapi/src" ]; then
        echo "📄 Syncing src to /home/app/src (preserving existing files)..."
        mkdir -p /home/app/src
        cp -rn /fastapi/src/. /home/app/src/

        # Ensure LF line endings for src files
        find /home/app/src -type f -name "*.py" -exec sed -i 's/\r$//' {} +
    fi
fi

# Final ownership check
fix_ownership
[ ! -f /home/app/.env ] || chmod 600 /home/app/.env

if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ]; then
    # Clean up legacy directories if they exist (renamed to src)
    for legacy in "/home/app/appsite" "/home/app/apisite" "/home/app/app"; do
        if [ -d "$legacy" ]; then
            echo "🧹 Removing legacy directory: $legacy..."
            rm -rf "$legacy"
        fi
    done
else
    if [ -d "/fastapi/src" ] && [ ! -f "/home/app/src/main.py" ]; then
        echo "ℹ️  Production mode: using baked-in /fastapi/src code."
        cd /fastapi/src
    fi
fi

exec gosu app "$@"
