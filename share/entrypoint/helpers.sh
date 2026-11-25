# shellcheck shell=bash
# Shared helpers for the Chembience docker-entrypoint.sh scripts.
#
# Every core image copies share/ to /opt/share, so entrypoints source this file
# as /opt/share/entrypoint/helpers.sh. It only defines functions; sourcing it has
# no side effects.
#
# Globals read: CHEMBIENCE_UID, CHEMBIENCE_GID, CHEMBIENCE_RUNTIME_MODE,
#   APP_GROUP (set by ensure_app_user), CHEMBIENCE_PROD_OWNED_DIRS (set by
#   set_prod_owned_dirs).

# Normalize CHEMBIENCE_RUNTIME_MODE to "dev" or "prod" (accepts "production").
normalize_runtime_mode() {
    CHEMBIENCE_RUNTIME_MODE="$(echo "${CHEMBIENCE_RUNTIME_MODE:-dev}" | tr '[:upper:]' '[:lower:]')"
    if [ "${CHEMBIENCE_RUNTIME_MODE}" = "production" ]; then
        CHEMBIENCE_RUNTIME_MODE="prod"
    fi
}

# Ensure the 'app' user and a group for it exist, and set APP_GROUP:
# - prefer an existing "app" group,
# - else reuse the name of an existing group with CHEMBIENCE_GID,
# - else create "app" with CHEMBIENCE_GID.
ensure_app_user() {
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

    # Fail early (set -e) rather than later in gosu if the user is still missing.
    id app >/dev/null 2>&1
}

# set_prod_owned_dirs DIR...: directories chowned in addition to /home/app by
# fix_ownership in prod mode (e.g. /home/app/src).
set_prod_owned_dirs() {
    CHEMBIENCE_PROD_OWNED_DIRS="$*"
}

# Give /home/app to the app user. In dev mode only files not already owned by
# 'app' are changed, avoiding a slow full -R sweep on large bind mounts. In prod
# mode only /home/app and the set_prod_owned_dirs directories are touched.
fix_ownership() {
    if [ "${CHEMBIENCE_RUNTIME_MODE}" = "prod" ]; then
        local dir
        for dir in /home/app ${CHEMBIENCE_PROD_OWNED_DIRS:-}; do
            [ -d "$dir" ] && chown app:"$APP_GROUP" "$dir" 2>/dev/null || true
        done
        return 0
    fi
    find /home/app -not -user app -print0 2>/dev/null \
        | xargs -0 -r chown "app:$APP_GROUP" 2>/dev/null || true
}

cleanup_ownership() {
    echo "🧹 Finalizing ownership of /home/app..."
    fix_ownership
}

# sync_config SRC DST: copy a shipped config/doc file into APP_HOME only if DST
# is missing, so user edits on the bind mount survive restarts. Strips CRLF.
sync_config() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        sed -i 's/\r$//' "$dst" 2>/dev/null || true
    fi
}

# sync_file SRC DST: always refresh a shipped, Chembience-owned file (e.g. a
# sourced library) so it matches the image version. Strips CRLF.
sync_file() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    cp "$src" "$dst"
    sed -i 's/\r$//' "$dst"
}

# sync_script SRC DST: always refresh a shipped helper script so upgrading the
# image delivers fixes, strip CRLF, and mark it executable. Customize behavior
# through .env, not by editing these scripts; local edits are overwritten.
sync_script() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    sync_file "$src" "$dst"
    chmod +x "$dst"
}

# ensure_kv FILE VAR VALUE: append VAR=VALUE if VAR is not set in FILE.
ensure_kv() {
    local file="$1" var="$2" val="$3"
    if ! grep -E "^${var}=" "$file" >/dev/null 2>&1; then
        echo "${var}=${val}" >>"$file"
    fi
}

# sync_prod_bundle SRC_ROOT: sync the production Compose bundle, PROD tools,
# and Helm chart from an image directory (e.g. /django, /opt/rdkit) into
# /home/app/PROD. A legacy prod/ directory is left alone; *-prepare-prod
# migrates it to PROD/.
sync_prod_bundle() {
    local root="$1" tool
    if [ ! -d "/home/app/prod" ]; then
        mkdir -p "/home/app/PROD"
        sync_config "$root/PROD/compose.yaml"          "/home/app/PROD/compose.yaml"
        sync_config "$root/PROD/compose.external.yaml" "/home/app/PROD/compose.external.yaml"
        for tool in psql db-backup db-restore db-cleanup; do
            sync_script "$root/prod-tools/$tool" "/home/app/PROD/$tool"
        done
        sync_config "$root/prod-tools/README.md" "/home/app/PROD/README.md"
    fi
    mkdir -p "/home/app/PROD/k8s"
    if [ ! -d "/home/app/PROD/k8s/chart" ]; then
        cp -a "$root/k8s" "/home/app/PROD/k8s/chart"
    fi
    sync_config "$root/k8s/README.md"                  "/home/app/PROD/k8s/README.md"
    sync_config "$root/k8s/values.override.yaml.example" "/home/app/PROD/k8s/values.override.yaml.example"
}

# seed_ignore_files: install the shipped .gitignore/.dockerignore/.gitattributes
# when missing, and make sure database data and generated Helm values stay
# out of Git and Docker build contexts.
seed_ignore_files() {
    local name
    for name in .gitignore .dockerignore .gitattributes; do
        [ -f "/$name" ] && [ ! -f "/home/app/$name" ] && cp "/$name" "/home/app/$name"
    done
    if [ -f "/home/app/.gitignore" ]; then
        if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.gitignore"; then
            {
                echo ""
                echo "# Added by entrypoint"
                echo "postgres/postgres_data"
            } >> "/home/app/.gitignore"
        fi
        if ! grep -Eq "^PROD/k8s/values\.generated\.yaml([[:space:]]|#|$)" "/home/app/.gitignore"; then
            {
                echo "PROD/k8s/values.generated.yaml"
                echo "PROD/k8s/values.override.yaml"
            } >> "/home/app/.gitignore"
        fi
    fi
    if [ -f "/home/app/.dockerignore" ]; then
        if ! grep -Eq "^postgres/postgres_data/?([[:space:]]|#|$)" "/home/app/.dockerignore"; then
            {
                echo ""
                echo "# Added by entrypoint"
                echo "postgres/postgres_data"
            } >> "/home/app/.dockerignore"
        fi
    fi
    return 0
}
