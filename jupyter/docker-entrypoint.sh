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
[ -f "/jupyter/docker-compose.yml" ] && cp "/jupyter/docker-compose.yml" "/home/app/docker-compose.yml"
[ -f "/jupyter/Dockerfile" ] && cp "/jupyter/Dockerfile" "/home/app/Dockerfile"
[ -f "/jupyter/requirements.txt" ] && cp "/jupyter/requirements.txt" "/home/app/requirements.txt"
[ -f "/jupyter/app-requirements.txt" ] && cp "/jupyter/app-requirements.txt" "/home/app/app-requirements.txt"
[ -f "/jupyter/README.md" ] && cp "/jupyter/README.md" "/home/app/README.md"

sync_script() {
    src="$1"
    dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        chmod +x "$dst"
        python3 -c "import os; content=open('$dst', 'rb').read().replace(b'\r\n', b'\n'); open('$dst', 'wb').write(content)"
    fi
}

sync_script "/jupyter/psql" "/home/app/psql"
sync_script "/jupyter/jupyter-init" "/home/app/jupyter-init"
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

    python3 -c "import os; f='/home/app/.env'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
fi

# Sync app if it exists in /jupyter/app
if [ -d "/jupyter/app/notebooks" ] && [ ! -d "/home/app/notebooks" ]; then
    echo "📄 Syncing notebooks to /home/app/notebooks..."
    cp -r "/jupyter/app/notebooks" "/home/app/notebooks"
fi

# Final ownership check
chown -R app:"$APP_GROUP" /home/app

exec gosu app "$@"
