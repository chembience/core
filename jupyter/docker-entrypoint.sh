#!/bin/bash
set -e

CHEMBIENCE_UID="${CHEMBIENCE_UID:-1000}"
CHEMBIENCE_GID="${CHEMBIENCE_GID:-1000}"

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
    find /home/app -not -user app -print0 2>/dev/null \
        | xargs -0 -r chown "app:$APP_GROUP" 2>/dev/null || true
}
cleanup_ownership() {
    echo "🧹 Finalizing ownership of /home/app..."
    fix_ownership
}
trap cleanup_ownership EXIT

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
    cp "$src" "${dst}.dist"
    sed -i 's/\r$//' "${dst}.dist" 2>/dev/null || true
}

# sync_script: always refresh helper scripts, strip CRLF, mark executable.
sync_script() {
    src="$1"; dst="$2"
    [ -f "$src" ] || return 0
    cp "$src" "$dst"
    chmod +x "$dst"
    sed -i 's/\r$//' "$dst"
}

echo "📄 Syncing internal configuration files to /home/app..."
sync_config "/jupyter/docker-compose.yml"    "/home/app/docker-compose.yml"
sync_config "/jupyter/Dockerfile"            "/home/app/Dockerfile"
sync_config "/jupyter/requirements.txt"      "/home/app/requirements.txt"
sync_config "/jupyter/app-requirements.txt"  "/home/app/app-requirements.txt"
sync_config "/jupyter/README.md"             "/home/app/README.md"
sync_script "/jupyter/psql"                  "/home/app/psql"
sync_script "/jupyter/jupyter-init"          "/home/app/jupyter-init"
[ -f "/.gitignore" ] && cp "/.gitignore" "/home/app/.gitignore"

# Create .env from example if it doesn't exist
if [ ! -f "/home/app/.env" ] && [ -f "/jupyter/.env.example" ]; then
    echo "📄 Creating initial .env from template..."
    cp "/jupyter/.env.example" "/home/app/.env"
    
    sed -i "s|^APP_HOME=.*|APP_HOME=./|g" "/home/app/.env"
    
    if [ -n "${APP_NAME}" ]; then
        if grep -q "^APP_NAME=" "/home/app/.env"; then
            sed -i "s|^APP_NAME=.*|APP_NAME=${APP_NAME}|g" "/home/app/.env"
        else
            echo "APP_NAME=${APP_NAME}" >> "/home/app/.env"
        fi
    fi
    
    if [ -n "${CHEMBIENCE_VERSION}" ]; then
        sed -i "s|^CHEMBIENCE_VERSION=.*|CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION}|g" "/home/app/.env"
    fi

    if [ -n "${JUPYTER_CONNECTION_PORT}" ]; then
        if grep -q "^JUPYTER_CONNECTION_PORT=" "/home/app/.env"; then
            sed -i "s|^JUPYTER_CONNECTION_PORT=.*|JUPYTER_CONNECTION_PORT=${JUPYTER_CONNECTION_PORT}|g" "/home/app/.env"
        else
            echo "JUPYTER_CONNECTION_PORT=${JUPYTER_CONNECTION_PORT}" >> "/home/app/.env"
        fi
    fi

    if [ -n "${POSTGRES_PASSWORD}" ]; then
        if grep -q "^POSTGRES_PASSWORD=" "/home/app/.env"; then
            sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|g" "/home/app/.env"
        else
            echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" >> "/home/app/.env"
        fi
    fi

    if [ -n "${POSTGRES_USER}" ]; then
        if grep -q "^POSTGRES_USER=" "/home/app/.env"; then
            sed -i "s|^POSTGRES_USER=.*|POSTGRES_USER=${POSTGRES_USER}|g" "/home/app/.env"
        else
            echo "POSTGRES_USER=${POSTGRES_USER}" >> "/home/app/.env"
        fi
    fi

    sed -i 's/\r$//' "/home/app/.env"
fi

# Sync app if it exists in /jupyter/app
if [ -d "/jupyter/app/notebooks" ] && [ ! -d "/home/app/notebooks" ]; then
    echo "📄 Syncing notebooks to /home/app/notebooks..."
    cp -r "/jupyter/app/notebooks" "/home/app/notebooks"
fi

# Final ownership check
fix_ownership

exec gosu app "$@"
