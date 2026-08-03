#!/bin/bash
set -euo pipefail

case "${POSTGRES_PASSWORD:-}" in
    ""|CHANGE_ME_BEFORE_RUNNING|secure-password-here|change-me-immediately)
        echo "❌ POSTGRES_PASSWORD must be set to a non-placeholder value." >&2
        exit 1
        ;;
esac

: "${POSTGRES_USER:?POSTGRES_USER must be set}"
: "${POSTGRES_NAME:?POSTGRES_NAME must be set}"

echo "🔧 Starting custom Postgres entrypoint..."

echo "📛 CHEMBIENCE_UID=${CHEMBIENCE_UID}, CHEMBIENCE_GID=${CHEMBIENCE_GID}"

# Create user and group if not exist
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

# Ensure home and data directories exist
mkdir -p /home/postgres
chown -R "$CHEMBIENCE_UID":"$CHEMBIENCE_GID" /home/postgres

# Also ensure any files copied to the volume are owned by the user
if [ -d "/home/postgres/postgres_data" ]; then
    chown -R "$CHEMBIENCE_UID":"$CHEMBIENCE_GID" /home/postgres/postgres_data
fi

DATA_DIR="/home/postgres/postgres_data"

if [ ! -f "${DATA_DIR}/PG_VERSION" ]; then
    echo "🗃 Initializing PostgreSQL data directory ..."
    gosu app initdb -D "${DATA_DIR}"

    echo "⚙️ Replacing PostgreSQL config files if available..."
    if [ -f /postgresql.conf ]; then
        echo "  ✅ Copying custom postgresql.conf"
        cp /postgresql.conf "${DATA_DIR}/postgresql.conf"
    else
        echo "  ⚠️  /postgresql.conf not found, using default"
    fi

    if [ -f /pg_hba.conf ]; then
        echo "  ✅ Copying custom pg_hba.conf"
        cp /pg_hba.conf "${DATA_DIR}/pg_hba.conf"
    else
        echo "  ⚠️  /pg_hba.conf not found, using default"
    fi

    echo "🚀 Starting temporary server to configure initial DB..."
    gosu app pg_ctl -D "${DATA_DIR}" -o "-c listen_addresses='localhost' -p 5432" -w start

    echo "USER $POSTGRES_USER"
    echo "NAME $POSTGRES_NAME"

    echo "📦 Creating user/database..."
    gosu app psql -v ON_ERROR_STOP=1 -p 5432 --dbname=postgres \
        --set=db_user="$POSTGRES_USER" \
        --set=db_password="$POSTGRES_PASSWORD" \
        --set=db_name="$POSTGRES_NAME" <<-'EOSQL'
        SELECT format(
            'CREATE ROLE %I WITH LOGIN PASSWORD %L SUPERUSER CREATEDB CREATEROLE REPLICATION',
            :'db_user', :'db_password'
        ) \gexec
        SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user') \gexec
EOSQL

    echo "📦 Initializing RDKit extension..."
    gosu app psql -v ON_ERROR_STOP=1 -p 5432 --dbname="$POSTGRES_NAME" <<-'EOSQL'
        CREATE EXTENSION IF NOT EXISTS rdkit;
EOSQL

    echo "📦 Granting privileges..."
    gosu app psql -v ON_ERROR_STOP=1 -p 5432 --dbname="$POSTGRES_NAME" \
        --set=db_user="$POSTGRES_USER" <<-'EOSQL'
        SELECT format('GRANT ALL ON SCHEMA public TO %I', :'db_user') \gexec
EOSQL

    echo "🛑 Stopping temporary server..."
    gosu app pg_ctl -D "${DATA_DIR}" -m fast -w stop

    # Final ownership check after initialization
    chown -R "$CHEMBIENCE_UID":"$CHEMBIENCE_GID" /home/postgres
else
    echo "📂 Using existing initialized data directory"
fi


#echo "🚀 Launching PostgreSQL server..."
#exec gosu app postgres -D "$DATA_DIR"

echo "🚦 Starting postgres main process: $*"
exec "$@"
