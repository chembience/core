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
[ -f "/fastapi/Dockerfile" ] && cp "/fastapi/Dockerfile" "/home/app/Dockerfile"
[ -f "/fastapi/requirements.txt" ] && cp "/fastapi/requirements.txt" "/home/app/requirements.txt"
[ -f "/fastapi/README.md" ] && cp "/fastapi/README.md" "/home/app/README.md"
[ -f "/fastapi/psql" ] && cp "/fastapi/psql" "/home/app/psql" && chmod +x "/home/app/psql" && python3 -c "import os; f='/home/app/psql'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
[ -f "/fastapi/fastapi-init" ] && cp "/fastapi/fastapi-init" "/home/app/fastapi-init" && chmod +x "/home/app/fastapi-init" && python3 -c "import os; f='/home/app/fastapi-init'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
[ -f "/fastapi/fastapi-run" ] && cp "/fastapi/fastapi-run" "/home/app/fastapi-run" && chmod +x "/home/app/fastapi-run" && python3 -c "import os; f='/home/app/fastapi-run'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
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

if [ ! -f "/home/app/appsite/main.py" ]; then
    echo "🚀 Initializing /home/app/appsite with a FastAPI prototype..."
    mkdir -p /home/app/appsite
    chown app:"$APP_GROUP" /home/app/appsite
    
    gosu app bash <<EOF
    set -x
    set -e
    cd /home/app/appsite

    cat <<EOPY > main.py
from fastapi import FastAPI, Depends
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from rdkit import Chem
import os

app = FastAPI(title="Chembience FastAPI Prototype")

# Database configuration
POSTGRES_USER = os.getenv("POSTGRES_USER", "chembience")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "secure-password-here")
POSTGRES_NAME = os.getenv("POSTGRES_NAME", "chembience")
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5433")

SQLALCHEMY_DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_NAME}"

print(f"DEBUG: Connecting to {POSTGRES_HOST}:{POSTGRES_PORT} as {POSTGRES_USER}")
print(f"DEBUG: Using password: {POSTGRES_PASSWORD}")

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Example Model
class Molecule(Base):
    __tablename__ = "molecules"
    id = Column(Integer, primary_key=True, index=True)
    smiles = Column(String, unique=True, index=True)

Base.metadata.create_all(bind=engine)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"message": "Welcome to Chembience FastAPI Prototype"}

@app.get("/rdkit-info")
def rdkit_info():
    return {"rdkit_version": Chem.rdBase.rdkitVersion}

@app.get("/mol/{smiles}")
def get_mol(smiles: str):
    mol = Chem.MolFromSmiles(smiles)
    if mol:
        return {"smiles": smiles, "molblock": Chem.MolToMolBlock(mol)}
    return {"error": "Invalid SMILES"}
EOPY
EOF
    # Ensure all created files have correct ownership and line endings
    gosu app bash <<EOF
    set -x
    set -e
    cd /home/app/appsite
    python3 -c "import os; f='main.py'; content=open(f, 'rb').read().replace(b'\r\n', b'\n'); open(f, 'wb').write(content)"
EOF
fi

# Final ownership check
chown -R app:"$APP_GROUP" /home/app

exec gosu app "$@"
