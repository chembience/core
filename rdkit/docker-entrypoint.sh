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

# Create user if missing (bind it to the chosen group)
if ! id "app" >/dev/null 2>&1; then
    echo "➕ Creating user 'app' with UID $CHEMBIENCE_UID and group $APP_GROUP..."
    useradd --shell /bin/bash -u "${CHEMBIENCE_UID}" -g "${APP_GROUP}" -o -c "" -M app
else
    echo "✅ User 'app' already exists."
fi

# Safety check: don't try gosu if user still doesn't exist
id app >/dev/null 2>&1

export PYTHONPATH=/home/app:/share:$PYTHONPATH

fix_ownership() {
    if [ "${CHEMBIENCE_RUNTIME_MODE}" = "prod" ]; then
        [ -d /home/app ] && chown app:"${APP_GROUP}" /home/app 2>/dev/null || true
        return 0
    fi
    find /home/app -not -user app -print0 2>/dev/null \
        | xargs -0 -r chown "app:${APP_GROUP}" 2>/dev/null || true
}

# Initialize app context if missing or if it looks like a django app
if [ "${CHEMBIENCE_RUNTIME_MODE}" != "prod" ] && { [ ! -f "/home/app/.rdkit-init" ] || [ -d "/home/app/src" ]; }; then
    # ONLY initialize if we are NOT in a django container.
    # We can check for existence of /django (copied in django/Dockerfile)
    if [ -d "/django" ]; then
        echo "✅ Django container detected, skipping rdkit initialization."
    else
        echo "🚀 Initializing /home/app for rdkit app..."
        cp /opt/rdkit/run /home/app/run
        cp /opt/rdkit/shell /home/app/shell
        cp /opt/rdkit/rdkit-init /home/app/rdkit-init
        cp /opt/rdkit/rdkit-configure /home/app/rdkit-configure
        cp /opt/rdkit/rdkit-prepare-prod /home/app/rdkit-prepare-prod
        cp /opt/rdkit/psql /home/app/psql
        [ ! -f "/home/app/docker-compose.yml" ] && cp /opt/rdkit/docker-compose.yml /home/app/docker-compose.yml
        [ ! -f "/home/app/Dockerfile" ] && cp /opt/rdkit/Dockerfile /home/app/Dockerfile
        [ ! -f "/home/app/Dockerfile.prod" ] && cp /opt/rdkit/Dockerfile.prod /home/app/Dockerfile.prod
        if [ ! -d "/home/app/prod" ]; then
            mkdir -p /home/app/PROD
            [ ! -f "/home/app/PROD/compose.yaml" ] && cp /opt/rdkit/PROD/compose.yaml /home/app/PROD/compose.yaml
            [ ! -f "/home/app/PROD/compose.external.yaml" ] && cp /opt/rdkit/PROD/compose.external.yaml /home/app/PROD/compose.external.yaml
            [ ! -f "/home/app/PROD/psql" ] && cp /opt/rdkit/prod-tools/psql /home/app/PROD/psql
            [ ! -f "/home/app/PROD/db-backup" ] && cp /opt/rdkit/prod-tools/db-backup /home/app/PROD/db-backup
            [ ! -f "/home/app/PROD/db-restore" ] && cp /opt/rdkit/prod-tools/db-restore /home/app/PROD/db-restore
            [ ! -f "/home/app/PROD/db-cleanup" ] && cp /opt/rdkit/prod-tools/db-cleanup /home/app/PROD/db-cleanup
            [ ! -f "/home/app/PROD/README.md" ] && cp /opt/rdkit/prod-tools/README.md /home/app/PROD/README.md
            chmod +x /home/app/PROD/psql /home/app/PROD/db-backup /home/app/PROD/db-restore /home/app/PROD/db-cleanup
        fi
        mkdir -p /home/app/PROD/k8s
        [ ! -d "/home/app/PROD/k8s/chart" ] && cp -a /opt/rdkit/k8s /home/app/PROD/k8s/chart
        [ ! -f "/home/app/PROD/k8s/README.md" ] && cp /opt/rdkit/prod-tools/k8s/README.md /home/app/PROD/k8s/README.md
        [ ! -f "/home/app/PROD/k8s/values.override.yaml.example" ] && cp /opt/rdkit/prod-tools/k8s/values.override.yaml.example /home/app/PROD/k8s/values.override.yaml.example
        [ ! -f "/home/app/README.md" ] && cp /opt/rdkit/README.md /home/app/README.md
        [ -f "/.gitignore" ] && [ ! -f "/home/app/.gitignore" ] && cp "/.gitignore" "/home/app/.gitignore"
        [ -f "/.dockerignore" ] && [ ! -f "/home/app/.dockerignore" ] && cp "/.dockerignore" "/home/app/.dockerignore"
        [ -f "/.gitattributes" ] && [ ! -f "/home/app/.gitattributes" ] && cp "/.gitattributes" "/home/app/.gitattributes"
        if [ -f "/home/app/.gitignore" ]; then
            if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.gitignore"; then
                echo "" >> "/home/app/.gitignore"
                echo "# Added by entrypoint" >> "/home/app/.gitignore"
                echo "postgres/postgres_data" >> "/home/app/.gitignore"
            fi
            if ! grep -Eq "^PROD/k8s/values\.generated\.yaml([[:space:]]|#|$)" "/home/app/.gitignore"; then
                echo "PROD/k8s/values.generated.yaml" >> "/home/app/.gitignore"
                echo "PROD/k8s/values.override.yaml" >> "/home/app/.gitignore"
            fi
        fi
        if [ -f "/home/app/.dockerignore" ]; then
            if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.dockerignore"; then
                echo "" >> "/home/app/.dockerignore"
                echo "# Added by entrypoint" >> "/home/app/.dockerignore"
                echo "postgres/postgres_data" >> "/home/app/.dockerignore"
            fi
        fi
        
    # Create .env file in /home/app
    if [ ! -f "/home/app/.env" ]; then
        echo "📝 Creating .env file in /home/app..."
        {
            echo "# ⚠️ AUTO-GENERATED FILE - DO NOT EDIT MANUALLY IF YOU WANT TO PERSIST CHANGES"
            echo "# This file was generated by the Chembience initialization script."
            echo ""
            echo "CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION:-latest}"
            echo "CHEMBIENCE_IMAGE_TAG=${CHEMBIENCE_VERSION:-latest}"
            echo "APP_NAME=${APP_NAME:-app}"
            echo "APP_HOME=."
            echo "CHEMBIENCE_UID=${CHEMBIENCE_UID}"
            echo "CHEMBIENCE_GID=${CHEMBIENCE_GID}"
            echo "POSTGRES_USER=${POSTGRES_USER:-chembience}"
            echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
            echo "POSTGRES_NAME=${POSTGRES_NAME:-chembience}"
            echo "POSTGRES_HOST=${POSTGRES_HOST:-postgres}"
            echo "POSTGRES_PORT=\${POSTGRES_PORT:-5432}"
        } > /home/app/.env
        
        # Ensure LF line endings
        sed -i 's/\r$//' "/home/app/.env"
    fi

        chmod +x /home/app/run /home/app/shell /home/app/rdkit-init /home/app/rdkit-configure /home/app/rdkit-prepare-prod /home/app/psql
        
        # Clean up django-specific files if they exist
        rm -rf /home/app/appsite /home/app/apisite /home/app/src /home/app/django-init /home/app/django-manage-py
        
        touch /home/app/.rdkit-init
    fi
fi

if [ ! -f "/home/app/requirements.txt" ]; then
    cp /opt/rdkit/app-requirements.txt /home/app/requirements.txt
fi

# Ensure all files in /home/app are owned by the app user (selective).
fix_ownership
[ ! -f /home/app/.env ] || chmod 600 /home/app/.env

exec gosu app "$@"
