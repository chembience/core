#!/bin/bash
set -e

CHEMBIENCE_UID="${CHEMBIENCE_UID:-1000}"
CHEMBIENCE_GID="${CHEMBIENCE_GID:-1000}"

# Pick a group to use:
# - Prefer an existing "app" group
# - Else, if the requested GID already exists, reuse that group name
# - Else, create "app" with the requested GID
if getent group app >/dev/null 2>&1; then
    APP_GROUP="app"
elif getent group "${CHEMBIENCE_GID}" >/dev/null 2>&1; then
    APP_GROUP="$(getent group "${CHEMBIENCE_GID}" | cut -d: -f1)"
else
    groupadd -g "${CHEMBIENCE_GID}" app
    APP_GROUP="app"
fi

# Create user if missing (bind it to the chosen group)
if ! id "app" >/dev/null 2>&1; then
    useradd --shell /bin/bash -u "${CHEMBIENCE_UID}" -g "${APP_GROUP}" -o -c "" -M app
fi

# Safety check: don't try gosu if user still doesn't exist
id app >/dev/null 2>&1

export PYTHONPATH=/home/app:/share:$PYTHONPATH

exec gosu app "$@"

