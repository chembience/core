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
        [ -d /home/app/notebooks ] && chown app:"$APP_GROUP" /home/app/notebooks 2>/dev/null || true
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
# Refresh a ".dist" sibling so users can diff against the shipped version.
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
    sync_config "/jupyter/docker-compose.yml"    "/home/app/docker-compose.yml"
    sync_config "/jupyter/Dockerfile"            "/home/app/Dockerfile"
    sync_config "/jupyter/Dockerfile.prod"       "/home/app/Dockerfile.prod"
    sync_config "/jupyter/requirements.txt"      "/home/app/requirements.txt"
    sync_config "/jupyter/app-requirements.txt"  "/home/app/app-requirements.txt"
    sync_config "/jupyter/README.md"             "/home/app/README.md"
    sync_script "/jupyter/psql"                  "/home/app/psql"
    sync_script "/jupyter/jupyter-init"          "/home/app/jupyter-init"
    sync_script "/jupyter/jupyter-configure"     "/home/app/jupyter-configure"
    sync_script "/jupyter/jupyter-prepare-prod"  "/home/app/jupyter-prepare-prod"
    [ -f "/.gitignore" ] && [ ! -f "/home/app/.gitignore" ] && cp "/.gitignore" "/home/app/.gitignore"
    [ -f "/.dockerignore" ] && [ ! -f "/home/app/.dockerignore" ] && cp "/.dockerignore" "/home/app/.dockerignore"
    [ -f "/.gitattributes" ] && [ ! -f "/home/app/.gitattributes" ] && cp "/.gitattributes" "/home/app/.gitattributes"
    if [ -f "/home/app/.gitignore" ]; then
        if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.gitignore"; then
            echo "" >> "/home/app/.gitignore"
            echo "# Added by entrypoint" >> "/home/app/.gitignore"
            echo "postgres/postgres_data" >> "/home/app/.gitignore"
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

gen_token() {
    # Prefer Python's secrets for a strong, URL-safe token; fallback to openssl; last resort: hexdump
    local tok=""
    if command -v python >/dev/null 2>&1; then
        tok="$(python - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
)"
    fi
    if [ -z "$tok" ] && command -v openssl >/dev/null 2>&1; then
        tok="$(openssl rand -hex 32 2>/dev/null || true)"
    fi
    if [ -z "$tok" ]; then
        tok="$(hexdump -n 32 -v -e '/1 "%02x"' /dev/urandom 2>/dev/null || date +%s)"
    fi
    echo "$tok"
}

if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ] && [ ! -f "/home/app/.env" ]; then
    echo "📝 Creating minimal .env for Jupyter in /home/app..."
    {
        echo "# ⚠️ AUTO-GENERATED FILE - INITIAL TEMPLATE"
        echo "# Generated by Chembience Jupyter entrypoint"
        echo ""
        echo "CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION:-latest}"
        echo "CHEMBIENCE_IMAGE_TAG=${CHEMBIENCE_VERSION:-latest}"
        echo "APP_NAME=${APP_NAME:-app}"
        echo "APP_HOME=."
        echo "CHEMBIENCE_UID=${CHEMBIENCE_UID}"
        echo "CHEMBIENCE_GID=${CHEMBIENCE_GID}"
        echo "JUPYTER_CONNECTION_PORT=${JUPYTER_CONNECTION_PORT:-8888}"
        echo "POSTGRES_USER=${POSTGRES_USER:-chembience}"
        echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
        echo "POSTGRES_NAME=${POSTGRES_NAME:-chembience}"
        echo "POSTGRES_HOST=${POSTGRES_HOST:-postgres}"
        echo "POSTGRES_PORT=${POSTGRES_PORT:-5432}"
    } > "/home/app/.env"

    # Persist a pinned Jupyter token: use inbound env if provided, else auto-generate a strong one
    if [ -n "${JUPYTER_TOKEN}" ]; then
        echo "JUPYTER_TOKEN=${JUPYTER_TOKEN}" >> "/home/app/.env"
    else
        gen="$(gen_token)" || gen=""
        if [ -n "$gen" ]; then
            echo "JUPYTER_TOKEN=${gen}" >> "/home/app/.env"
            echo "🔐 Generated JUPYTER_TOKEN and persisted to /home/app/.env"
        fi
    fi

    # Ensure LF line endings
    sed -i 's/\r$//' "/home/app/.env"
elif [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ]; then
    # Non-destructive reconciliation: ensure critical keys exist
    echo "🔁 Reconciling required keys in existing .env..."
    ensure_kv "/home/app/.env" "JUPYTER_CONNECTION_PORT" "${JUPYTER_CONNECTION_PORT:-8888}"
    # Ensure a token exists: prefer inbound env; else, generate if missing
    if [ -n "${JUPYTER_TOKEN}" ]; then
        ensure_kv "/home/app/.env" "JUPYTER_TOKEN" "${JUPYTER_TOKEN}"
    elif ! grep -E "^JUPYTER_TOKEN=" "/home/app/.env" >/dev/null 2>&1; then
        gen="$(gen_token)" || gen=""
        if [ -n "$gen" ]; then
            echo "JUPYTER_TOKEN=${gen}" >> "/home/app/.env"
            echo "🔐 Generated missing JUPYTER_TOKEN and persisted to /home/app/.env"
        fi
    fi
fi

# Sync app if it exists in /jupyter/app
if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ] && [ -d "/jupyter/app/notebooks" ] && [ ! -d "/home/app/notebooks" ]; then
    echo "📄 Syncing notebooks to /home/app/notebooks..."
    cp -r "/jupyter/app/notebooks" "/home/app/notebooks"
fi

# If no JUPYTER_TOKEN is present in the container env, but we have one persisted
# in the per-app .env, export it so the running Jupyter honors the pinned token.
if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ] && [ -z "${JUPYTER_TOKEN}" ] && [ -f "/home/app/.env" ]; then
    file_tok="$(grep -E '^JUPYTER_TOKEN=' /home/app/.env | head -n1 | cut -d= -f2- || true)"
    if [ -n "$file_tok" ]; then
        export JUPYTER_TOKEN="$file_tok"
        echo "🔑 Applied JUPYTER_TOKEN from /home/app/.env for this session."
    fi
fi

# Final ownership check
fix_ownership
[ ! -f /home/app/.env ] || chmod 600 /home/app/.env

exec gosu app "$@"
