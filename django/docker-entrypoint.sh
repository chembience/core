#!/bin/bash
set -e  # Exit immediately on error

echo "🔧 Entrypoint started..."
echo "Running as UID: $(id -u), GID: $(id -g)"
echo "CHEMBIENCE_UID: ${CHEMBIENCE_UID}, CHEMBIENCE_GID: ${CHEMBIENCE_GID}"

# Create user and group if they don't exist
if ! id "app" >/dev/null 2>&1; then
    echo "➕ Creating user 'app' (UID: $CHEMBIENCE_UID, GID: $CHEMBIENCE_GID)..."
    if getent group "$CHEMBIENCE_GID" >/dev/null 2>&1; then
        APP_GROUP="$(getent group "$CHEMBIENCE_GID" | cut -d: -f1)"
        echo "✅ Group with GID $CHEMBIENCE_GID already exists: $APP_GROUP"
    else
        groupadd -g "$CHEMBIENCE_GID" app
        APP_GROUP="app"
    fi
    useradd --shell /bin/bash -u "$CHEMBIENCE_UID" -g "$APP_GROUP" -o -c "" -M app
else
    echo "✅ User 'app' already exists."
fi

mkdir -p /home/app

# Initialize the Django project if not present
if [ ! -f /home/app/manage.py ] || [ -z "$(ls -A /home/app)" ]; then
    echo "📦 Initializing Django project in /home/app..."

    # Ensure /home/app exists and is writable by root (it should be already)
    mkdir -p /home/app
    
    cd /home/app

    echo "🚀 Running django-admin startproject with custom template..."
    # If appsite directory exists but manage.py is missing, django-admin startproject might fail
    # We use a temporary directory and move things if needed, or just run it and hope for the best.
    # Actually django-admin startproject appsite . --template... would be better if we are already in /home/app
    # Ensure it's owned by root for now so django-admin can write if it's running as root
    django-admin startproject appsite . --template=/home/template/appsite

    echo "📁 Creating backup directory..."
    mkdir -p /home/app/backup

    echo "📋 Copying starter files (non-overwriting)..."
    cp -n /.env.example /home/app/.env || echo "⚠️  .env already exists, skipping"
    cp -n /home/template/manage /home/app/manage || echo "⚠️  manage already exists, skipping"
    cp -n /docker-compose.yml /home/app/docker-compose.yml || echo "⚠️  docker-compose.yml already exists, skipping"
    # Also copy Dockerfile to make it fully self-contained
    cp -n /Dockerfile /home/app/Dockerfile || echo "⚠️  Dockerfile already exists, skipping"

    echo "🔒 Setting ownership to $CHEMBIENCE_UID:$CHEMBIENCE_GID..."
    chown -R "$CHEMBIENCE_UID":"$CHEMBIENCE_GID" /home/app
    
    # Also set correct permissions for scripts to be executable by the user
    chmod +x /home/app/manage || true
fi

# ALWAYS ensure ownership of /home/app in case volume was mounted with wrong permissions
echo "🔒 Ensuring ownership of /home/app for $CHEMBIENCE_UID:$CHEMBIENCE_GID..."
chown -R "$CHEMBIENCE_UID":"$CHEMBIENCE_GID" /home/app

# Move into the Django project directory
cd /home/app

echo "🚦 Starting main process: $*"
exec gosu app "$@"
