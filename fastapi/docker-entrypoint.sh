#!/bin/bash
set -e

CHEMBIENCE_UID="${CHEMBIENCE_UID:-1000}"
CHEMBIENCE_GID="${CHEMBIENCE_GID:-1000}"

if ! getent group app >/dev/null 2>&1; then
    if getent group "${CHEMBIENCE_GID}" >/dev/null 2>&1; then
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

echo "🔧 Ensuring correct ownership of /home/app..."
cleanup_ownership() {
    echo "🧹 Finalizing ownership of /home/app..."
    chown -R app:"$APP_GROUP" /home/app
}
trap cleanup_ownership EXIT

chown -R app:"$APP_GROUP" /home/app

echo "📄 Syncing internal configuration files to /home/app..."
[ -f "/fastapi/docker-compose.yml" ] && cp "/fastapi/docker-compose.yml" "/home/app/docker-compose.yml"
[ -f "/fastapi/docker-compose.override.yml" ] && cp "/fastapi/docker-compose.override.yml" "/home/app/docker-compose.override.yml"
[ -f "/fastapi/Dockerfile" ] && cp "/fastapi/Dockerfile" "/home/app/Dockerfile"
[ -f "/fastapi/requirements.txt" ] && cp "/fastapi/requirements.txt" "/home/app/requirements.txt"
[ -f "/fastapi/README.md" ] && cp "/fastapi/README.md" "/home/app/README.md"
sync_script() {
    src="$1"
    dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        chmod +x "$dst"
        python3 -c "import os; content=open('$dst', 'rb').read().replace(b'\r\n', b'\n'); open('$dst', 'wb').write(content)"
    fi
}

sync_script "/fastapi/psql" "/home/app/psql"
sync_script "/fastapi/db_backup" "/home/app/db_backup"
sync_script "/fastapi/db_restore" "/home/app/db_restore"
sync_script "/fastapi/db_cleanup" "/home/app/db_cleanup"
# fastapi-init is now expected to be in /fastapi/fastapi-init (synced from fastapi/app/fastapi-init in Dockerfile)
sync_script "/fastapi/fastapi-init" "/home/app/fastapi-init"
[ -f "/.gitignore" ] && cp "/.gitignore" "/home/app/.gitignore"

# Create .env from example if it doesn't exist
if [ ! -f "/home/app/.env" ] && [ -f "/fastapi/.env.example" ]; then
    echo "📄 Creating initial .env from template..."
    cp "/fastapi/.env.example" "/home/app/.env"
    
    # Customize .env with current application settings
    # Use sed to update or add variables
    sed -i "s|^APP_HOME=.*|APP_HOME=./|g" "/home/app/.env"
    
    if [ -n "${APP_NAME}" ]; then
        # If APP_NAME starts with -, remove it for the variable if needed, 
        # but here we likely want it as is for the image name in docker-compose
        if grep -q "^APP_NAME=" "/home/app/.env"; then
            sed -i "s|^APP_NAME=.*|APP_NAME=${APP_NAME}|g" "/home/app/.env"
        else
            echo "APP_NAME=${APP_NAME}" >> "/home/app/.env"
        fi
    fi
    
    if [ -n "${CHEMBIENCE_VERSION}" ]; then
        sed -i "s|^CHEMBIENCE_VERSION=.*|CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION}|g" "/home/app/.env"
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

    # Ensure LF line endings for .env
    python3 -c "import os; f='/home/app/.env'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
fi

# Ensure all synced files have correct ownership
chown -R app:"$APP_GROUP" /home/app

# Sync apisite from the image into the bind-mounted /home/app.
# The host bind mount (${APP_HOME}:/home/app) shadows the apisite/ baked into
# the image, so we must materialize it here on every start. We only copy files
# that don't already exist in the target so user edits are preserved across
# restarts, but missing files (e.g. main.py on a freshly created APP_HOME) are
# always restored — otherwise uvicorn fails with "Could not import module main".
if [ -d "/fastapi/apisite" ]; then
    echo "📄 Syncing apisite to /home/app/apisite (preserving existing files)..."
    mkdir -p /home/app/apisite
    cp -rn /fastapi/apisite/. /home/app/apisite/

    # Ensure LF line endings for apisite files
    find /home/app/apisite -type f -name "*.py" -exec python3 -c "import sys; f=sys.argv[1]; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)" {} \;
fi

# Final ownership check
chown -R app:"$APP_GROUP" /home/app

# Clean up appsite if it exists (renamed to apisite)
if [ -d "/home/app/appsite" ]; then
    echo "🧹 Removing legacy appsite directory..."
    rm -rf /home/app/appsite
fi

exec gosu app "$@"
