#!/bin/bash
set -e

CHEMBIENCE_UID="${CHEMBIENCE_UID:-1000}"
CHEMBIENCE_GID="${CHEMBIENCE_GID:-1000}"

# Generate a cryptographically strong Django SECRET_KEY.
# Prefer openssl; fall back to Python's secrets module (always present in this image).
# Output is URL-safe-ish and never contains the literal insecure default.
generate_django_secret_key() {
    local key
    key="$(openssl rand -base64 50 2>/dev/null | tr -d '\n' || true)"
    if [ -z "$key" ]; then
        key="$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))' 2>/dev/null || true)"
    fi
    if [ -z "$key" ]; then
        # Last-resort: /dev/urandom. Avoid the well-known insecure default.
        key="$(head -c 50 /dev/urandom | base64 | tr -d '\n')"
    fi
    printf '%s' "$key"
}

_INSECURE_DEFAULT_KEY='django-insecure-default-change-me-in-production'

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

# Ensure correct ownership and permissions for /home/app
echo "🔧 Ensuring correct ownership of /home/app..."
# We use a trap to ensure ownership is fixed even on failure
cleanup_ownership() {
    echo "🧹 Finalizing ownership of /home/app..."
    chown -R app:"$APP_GROUP" /home/app
}
trap cleanup_ownership EXIT

chown -R app:"$APP_GROUP" /home/app

# Initialize /home/app with helper scripts and Docker configuration
# We do this EVERY time to ensure helper scripts are present even if the volume mount wiped them
echo "📄 Syncing internal configuration files to /home/app..."
# These files are baked into the image in the /django/ directory
# Use gosu to copy them as the app user if possible, or chown after
[ -f "/django/docker-compose.yml" ] && cp "/django/docker-compose.yml" "/home/app/docker-compose.yml"
[ -f "/django/Dockerfile" ] && cp "/django/Dockerfile" "/home/app/Dockerfile"
[ -f "/django/requirements.txt" ] && cp "/django/requirements.txt" "/home/app/requirements.txt"
[ -f "/django/README.md" ] && cp "/django/README.md" "/home/app/README.md"
[ -f "/django/psql" ] && cp "/django/psql" "/home/app/psql" && chmod +x "/home/app/psql" && python3 -c "import os; f='/home/app/psql'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
[ -f "/django/django-init" ] && cp "/django/django-init" "/home/app/django-init" && chmod +x "/home/app/django-init" && python3 -c "import os; f='/home/app/django-init'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
[ -f "/django/django-manage-py" ] && cp "/django/django-manage-py" "/home/app/django-manage-py" && chmod +x "/home/app/django-manage-py" && python3 -c "import os; f='/home/app/django-manage-py'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
[ -f "/django/prod" ] && cp "/django/prod" "/home/app/prod" && chmod +x "/home/app/prod" && python3 -c "import os; f='/home/app/prod'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
[ -f "/.gitignore" ] && cp "/.gitignore" "/home/app/.gitignore"

# Create .env from example if it doesn't exist
if [ ! -f "/home/app/.env" ] && [ -f "/django/.env.example" ]; then
    echo "📄 Creating initial .env from template..."
    cp "/django/.env.example" "/home/app/.env"
    
    # Customize .env with current application settings
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

    # Ensure LF line endings for .env
    python3 -c "import os; f='/home/app/.env'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
fi

chown -R app:"$APP_GROUP" /home/app

# Initialize /home/app/appsite if it's empty or missing manage.py
if [ ! -f "/home/app/appsite/manage.py" ]; then
    echo "🚀 Initializing /home/app/appsite using django-admin..."
    # Ensure /home/app/appsite exists
    mkdir -p /home/app/appsite
    chown app:"$APP_GROUP" /home/app/appsite
    
    # Run initialization as the app user to avoid permission issues later
    gosu app bash <<EOF
    set -x
    set -e
    cd /home/app/appsite
    # Initialize Django project if not already present
    if [ ! -f "manage.py" ]; then
        django-admin startproject appsite .
    fi
    # Initialize 'simple' app
    if [ ! -d "simple" ]; then
        python manage.py startapp simple
        # Ensure we have a urls.py in the simple app
        touch simple/urls.py
    fi

    # Sync django-rdkit-test-app from /django/ to /home/app/appsite/ and rename it to django_rdkit_test_app
    if [ -d "/django/django-rdkit-test-app" ]; then
        echo "📦 Syncing django-rdkit-test-app to appsite..."
        mkdir -p /home/app/appsite/django_rdkit_test_app
        cp -r /django/django-rdkit-test-app/. /home/app/appsite/django_rdkit_test_app/
    fi
EOF

    echo "⚙️ Configuring Django settings..."
    # Update settings.py
    # 1. Add 'simple.apps.SimpleConfig' to INSTALLED_APPS
    # 2. Configure DATABASES for PostgreSQL
    # 3. Add shared path to sys.path
    # 4. Set other settings like ALLOWED_HOSTS, SECRET_KEY, DEBUG, etc.
    
    # Create the files as root but ensure they are in the right place and then chown
    cat <<EOF > /home/app/appsite/appsite/settings.py
"""
Django settings for appsite project.
"""
from pathlib import Path
import os
import sys

sys.path.append('/share')

BASE_DIR = Path(__file__).resolve().parent.parent

DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('1', 'true', 'yes', 'on')

# In production (DEBUG=False) we refuse to start with the insecure default key.
_default_secret = 'django-insecure-default-change-me-in-production'


def _load_secret_key_from_env_file():
    # Fallback for invocations that bypass the container entrypoint
    # (e.g. \`docker compose exec django python manage.py ...\`): read the
    # persisted per-project .env directly so management commands work without
    # the user having to re-export DJANGO_SECRET_KEY into the host environment.
    for candidate in ('/home/app/.env', os.path.join(str(BASE_DIR.parent), '.env')):
        try:
            with open(candidate, 'r', encoding='utf-8') as fh:
                for line in fh:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if not line.startswith('DJANGO_SECRET_KEY='):
                        continue
                    value = line.split('=', 1)[1].strip()
                    if (value.startswith("'") and value.endswith("'")) or \
                       (value.startswith('"') and value.endswith('"')):
                        value = value[1:-1]
                    if value and value != _default_secret:
                        return value
        except OSError:
            continue
    return None


SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', '') or ''
if not SECRET_KEY or SECRET_KEY == _default_secret:
    _fallback = _load_secret_key_from_env_file()
    if _fallback:
        SECRET_KEY = _fallback
        os.environ['DJANGO_SECRET_KEY'] = _fallback

if not DEBUG and (not SECRET_KEY or SECRET_KEY == _default_secret):
    raise RuntimeError(
        'DJANGO_SECRET_KEY is not set (or still uses the insecure default) '
        'while DJANGO_DEBUG is False. Refusing to start. Set DJANGO_SECRET_KEY '
        'to a long random string in your .env file.'
    )

ALLOWED_HOSTS = os.environ.get('DJANGO_VIRTUAL_HOSTNAME', 'localhost').split(",")
# Ensure the in-container healthcheck (curl http://localhost:8000/healthz/) always passes
# the Django host header validation, regardless of DJANGO_VIRTUAL_HOSTNAME.
for _h in ('localhost', '127.0.0.1'):
    if _h not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_h)

INSTALLED_APPS = [
    'simple.apps.SimpleConfig',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_rdkit',
    'django_rdkit_test_app',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'appsite.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'appsite.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': os.environ['POSTGRES_NAME'],
        'USER':  os.environ['POSTGRES_USER'],
        'PASSWORD': os.environ['POSTGRES_PASSWORD'],
        'HOST': os.environ['POSTGRES_HOST'],
        'PORT': os.environ.get('POSTGRES_INTERNAL_PORT', '5432')
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
# USE_L10N was deprecated in Django 4.0 and removed in 5.0; localization is always enabled.
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / "static"
MEDIA_ROOT = BASE_DIR / "media"
MEDIA_URL = "/media/"

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF

    echo "⚙️ Configuring appsite/urls.py..."
    cat <<EOF > /home/app/appsite/appsite/urls.py
from django.contrib import admin
from django.db import connection
from django.http import HttpResponse
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static


def healthz(request):
    # Lightweight liveness/readiness probe used by the Docker healthcheck.
    # Verifies the WSGI worker is alive and the database is reachable.
    try:
        connection.ensure_connection()
    except Exception as exc:  # pragma: no cover - probe path
        return HttpResponse("db-unavailable: %s" % exc, status=503)
    return HttpResponse("ok")


urlpatterns = [
    path('healthz/', healthz),
    path('simple/', include('simple.urls')),
    path('admin/', admin.site.urls),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
else:
    # Fallback for serving media files via Gunicorn if no Nginx is used
    from django.views.static import serve
    from django.urls import re_path
    urlpatterns += [
        re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    ]
EOF

    echo "⚙️ Configuring simple app..."
    cat <<EOF > /home/app/appsite/simple/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('resolver/<str:smiles>', views.resolver),
]
EOF

    cat <<EOF > /home/app/appsite/simple/views.py
from django.http import HttpResponse
from rdkit import Chem

def resolver(request, smiles):
    mol = Chem.MolFromSmiles(smiles)
    if mol:
        return HttpResponse(Chem.MolToInchi(mol))
    else:
        return HttpResponse("Invalid SMILES", status=400)
EOF

    cat <<EOF > /home/app/appsite/simple/models.py
from django.db import models

class Simple(models.Model):
    text = models.CharField(max_length=200)
    pub_date = models.DateTimeField('date published')
EOF

    # Go back to /
    cd /

    echo "⚙️ Running collectstatic..."
    # We need settings.py to be there for collectstatic
    # Also ensure static/media dirs exist and are owned by app
    mkdir -p /home/app/appsite/static /home/app/appsite/media
    chown -R app:"$APP_GROUP" /home/app/appsite/static /home/app/appsite/media
    # Note: collectstatic might fail if database is not reachable and settings.py expects it.
    # We use a dummy secret key and ignore database for collectstatic if possible.
    gosu app bash -c "PYTHONPATH=/home/app/appsite DJANGO_SECRET_KEY=dummy python /home/app/appsite/manage.py collectstatic --noinput --clear" || echo "⚠️ collectstatic failed, but continuing..."

    # Clean up rdkit-specific files if they exist
    rm -rf /home/app/run /home/app/shell /home/app/.rdkit-init

    # Final chown to ensure everything created during init is owned by app
    chown -R app:"$APP_GROUP" /home/app


    echo "📝 Creating .env file in /home/app..."
    {
        echo "# ⚠️ AUTO-GENERATED FILE - DO NOT EDIT MANUALLY IF YOU WANT TO PERSIST CHANGES"
        echo "# This file was generated by the Chembience initialization script."
        echo ""
        echo "CHEMBIENCE_VERSION=${CHEMBIENCE_VERSION:-latest}"
        echo "CHEMBIENCE_IMAGE_TAG=${CHEMBIENCE_VERSION:-latest}"
        echo "APP_NAME=${APP_NAME:--app}"
        echo "APP_HOME=."
        echo "CHEMBIENCE_UID=${CHEMBIENCE_UID}"
        echo "CHEMBIENCE_GID=${CHEMBIENCE_GID}"
        echo "DJANGO_VIRTUAL_HOSTNAME=${DJANGO_VIRTUAL_HOSTNAME}"
        echo "DJANGO_CONNECTION_PORT=${DJANGO_CONNECTION_PORT:-8001}"
        # Use the inbound DJANGO_SECRET_KEY if the user set one in the host .env;
        # otherwise generate a strong one (persisted here so it survives restarts).
        _env_key="${DJANGO_SECRET_KEY:-}"
        if [ -z "$_env_key" ] || [ "$_env_key" = "$_INSECURE_DEFAULT_KEY" ]; then
            _env_key="$(generate_django_secret_key)"
            echo "🔐 Generated DJANGO_SECRET_KEY (persisted in ./.env; treat that file as a secret)." >&2
        fi
        # Single-quote to defend against +, /, = or any future special chars.
        echo "DJANGO_SECRET_KEY='${_env_key}'"
        # Export it so the gunicorn process started right after this init can read it.
        export DJANGO_SECRET_KEY="$_env_key"
        echo "DJANGO_DEBUG=${DJANGO_DEBUG:-False}"
        echo "DJANGO_SUPERUSER_USERNAME=${DJANGO_SUPERUSER_USERNAME}"
        echo "DJANGO_SUPERUSER_EMAIL=${DJANGO_SUPERUSER_EMAIL}"
        echo "DJANGO_SUPERUSER_PASSWORD=${DJANGO_SUPERUSER_PASSWORD}"
        echo "POSTGRES_USER=${POSTGRES_USER}"
        echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
        echo "POSTGRES_NAME=${POSTGRES_NAME}"
        echo "POSTGRES_HOST=${POSTGRES_HOST}"
        echo "POSTGRES_HOST_PORT=${POSTGRES_HOST_PORT:-${POSTGRES_PORT:-5433}}"
    } > /home/app/.env
    chown app:"$APP_GROUP" /home/app/.env

    # Create a README.md in /home/app
    echo "📖 Creating README.md in /home/app..."
    {
        echo "# Chembience Application: /home/app"
        echo ""
        echo "This directory contains a self-contained Chembience application."
        echo "It was initialized from a template and includes its own Docker configuration."
        echo ""
        echo "## Quick Start"
        echo ""
        echo "To start the application, run:"
        echo "\`\`\`bash"
        echo "docker compose up -d"
        echo "\`\`\`"
        echo ""
        echo "## Directory Structure"
        echo ""
        echo "- \`appsite/\`: Django application code."
        echo "- \`postgres/\`: PostgreSQL data and configuration (initialized on first start)."
        echo "- \`docker-compose.yml\`: Defines the services (django, postgres)."
        echo "- \`Dockerfile\`: Used for building the django service."
        echo "- \`requirements.txt\`: Python requirements for the application."
        echo "- \`django-init\`: Script to initialize Django (migrations, superuser)."
        echo "- \`django-manage-py\`: Wrapper for Django manage.py."
        echo "- \`psql\`: Helper script to access the database."
        echo "- \`.env\`: Environment variables for the application."
        echo ""
        echo "## Maintenance"
        echo ""
        echo "- To rebuild the application image: \`docker compose build\`"
        echo "- To view logs: \`docker compose logs -f\`"
    } > /home/app/README.md
    chown app:"$APP_GROUP" /home/app/README.md
fi

# Sync django-rdkit-test-app from /django/ to /home/app/appsite/ and rename it to django_rdkit_test_app
# We do this every time to ensure it's up to date even if the volume mount is persistent
if [ -d "/django/django-rdkit-test-app" ]; then
    echo "📦 Syncing django-rdkit-test-app to appsite..."
    mkdir -p /home/app/appsite/django_rdkit_test_app
    cp -r /django/django-rdkit-test-app/. /home/app/appsite/django_rdkit_test_app/
    chown -R app:"$APP_GROUP" /home/app/appsite/django_rdkit_test_app
fi

# Final ownership check before starting (outside the init block too)
chown -R app:"$APP_GROUP" /home/app

# Debug info
echo "📂 Contents of /home/app/appsite:"
ls -F /home/app/appsite
echo "🐍 PYTHONPATH: $PYTHONPATH"

export PYTHONPATH=/home/app/appsite:/share${PYTHONPATH:+:$PYTHONPATH}

# Ensure DJANGO_SECRET_KEY is available to the server process on every start.
# Priority: 1) inbound container env, 2) persisted project .env, 3) generate (and persist).
if [ -z "${DJANGO_SECRET_KEY:-}" ] || [ "${DJANGO_SECRET_KEY}" = "$_INSECURE_DEFAULT_KEY" ]; then
    if [ -f /home/app/.env ] && grep -q '^DJANGO_SECRET_KEY=' /home/app/.env; then
        # Strip optional surrounding single/double quotes.
        _persisted_key="$(grep '^DJANGO_SECRET_KEY=' /home/app/.env | head -n1 | cut -d= -f2-)"
        _persisted_key="${_persisted_key%\'}"; _persisted_key="${_persisted_key#\'}"
        _persisted_key="${_persisted_key%\"}"; _persisted_key="${_persisted_key#\"}"
        if [ -n "$_persisted_key" ] && [ "$_persisted_key" != "$_INSECURE_DEFAULT_KEY" ]; then
            export DJANGO_SECRET_KEY="$_persisted_key"
            echo "🔐 Loaded DJANGO_SECRET_KEY from project .env."
        fi
    fi
fi
if [ -z "${DJANGO_SECRET_KEY:-}" ] || [ "${DJANGO_SECRET_KEY}" = "$_INSECURE_DEFAULT_KEY" ]; then
    _gen_key="$(generate_django_secret_key)"
    export DJANGO_SECRET_KEY="$_gen_key"
    if [ -w /home/app/.env ]; then
        # Persist for next restart (or create the line if it didn't exist).
        if grep -q '^DJANGO_SECRET_KEY=' /home/app/.env; then
            sed -i "s|^DJANGO_SECRET_KEY=.*|DJANGO_SECRET_KEY='${_gen_key}'|" /home/app/.env
        else
            echo "DJANGO_SECRET_KEY='${_gen_key}'" >> /home/app/.env
        fi
        chown app:"$APP_GROUP" /home/app/.env || true
    fi
    echo "🔐 Generated DJANGO_SECRET_KEY on the fly (persisted to ./.env when writable)."
fi

exec gosu app "$@"