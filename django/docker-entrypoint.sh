#!/bin/bash
set -e

CHEMBIENCE_UID="${CHEMBIENCE_UID:-1000}"
CHEMBIENCE_GID="${CHEMBIENCE_GID:-1000}"

# Pick a group to use:
# - Prefer an existing "app" group
# - Else, if the requested GID already exists, reuse that group name
# - Else, create "app" with the requested GID
if ! getent group app >/dev/null 2>&1; then
    if getent group "${CHEMBIENCE_GID}" >/dev/null 2>&1; then
        # Group with this GID already exists, rename it to app or just use it?
        # Actually, if we want the user 'app' to have this GID, we should just use the existing group name.
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

# Create user if missing (bind it to the chosen group)
if ! id "app" >/dev/null 2>&1; then
    echo "➕ Creating user 'app' with UID $CHEMBIENCE_UID and group $APP_GROUP..."
    useradd --shell /bin/bash -u "${CHEMBIENCE_UID}" -g "${APP_GROUP}" -o -c "" -M app
else
    echo "✅ User 'app' already exists."
fi

# Safety check: don't try gosu if user still doesn't exist
id app >/dev/null 2>&1

# Initialize /home/app if it's empty or missing appsite/manage.py
if [ ! -f "/home/app/appsite/manage.py" ]; then
    echo "🚀 Initializing /home/app/appsite from template..."
    # Ensure /home/app exists
    mkdir -p /home/app
    
    # If the template exists, copy it
    if [ -d "/home/template/appsite" ]; then
        mkdir -p /home/app/appsite
        cp -RT /home/template/appsite /home/app/appsite
    else
        echo "⚠️  Template /home/template/appsite not found!"
    fi

    # Initialize /home/app with docker-compose and Dockerfile
    echo "📄 Copying Docker configuration to /home/app..."
    [ -f "/django/docker-compose.yml" ] && cp "/django/docker-compose.yml" "/home/app/docker-compose.yml"
    [ -f "/django/Dockerfile" ] && cp "/django/Dockerfile" "/home/app/Dockerfile"

    # Create .env file in /home/app
    echo "📝 Creating .env file in /home/app..."
    {
        echo "CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION:-latest}"
        echo "APP_HOME=."
        echo "CHEMBIENCE_UID=${CHEMBIENCE_UID}"
        echo "CHEMBIENCE_GID=${CHEMBIENCE_GID}"
        echo "DJANGO_VIRTUAL_HOSTNAME=${DJANGO_VIRTUAL_HOSTNAME}"
        echo "DJANGO_CONNECTION_PORT=${DJANGO_CONNECTION_PORT}"
        echo "DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY:-$(openssl rand -base64 32 2>/dev/null || echo 'django-insecure-default-change-me-in-production')}"
        echo "DJANGO_DEBUG=${DJANGO_DEBUG:-True}"
        echo "DJANGO_SUPERUSER_USERNAME=${DJANGO_SUPERUSER_USERNAME}"
        echo "DJANGO_SUPERUSER_EMAIL=${DJANGO_SUPERUSER_EMAIL}"
        echo "DJANGO_SUPERUSER_PASSWORD=${DJANGO_SUPERUSER_PASSWORD}"
        echo "POSTGRES_USER=${POSTGRES_USER}"
        echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
        echo "POSTGRES_NAME=${POSTGRES_NAME}"
        echo "POSTGRES_HOST=${POSTGRES_HOST}"
        echo "POSTGRES_PORT=${POSTGRES_PORT}"
    } > /home/app/.env
fi

# Ensure correct ownership
chown -R app:"$APP_GROUP" /home/app

# Debug info
echo "📂 Contents of /home/app/appsite:"
ls -F /home/app/appsite
echo "🐍 PYTHONPATH: $PYTHONPATH"

export PYTHONPATH=/home/app/appsite:/share${PYTHONPATH:+:$PYTHONPATH}

exec gosu app "$@"