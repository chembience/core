# Chembience RDKit Application

This is the RDKit service for your Chembience project. It provides specialized chemical processing capabilities.

## Directory Structure

- `run`: Script for running RDKit-based workloads.
- `shell`: Helper script for accessing the RDKit environment.
- `psql`: Helper script for accessing the PostgreSQL database.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

To start the stack along with the PostgreSQL database:

```bash
docker compose up -d
```

To run a script in the RDKit environment:
```bash
./run your_script.py
```

To access the interactive shell:
```bash
./shell
```

For more information, see the root [README.md](../../README.md).

## Configuration

- Use `./rdkit-configure [--rebuild] [NEW_ENV_FILE]` to manage environment updates safely.
  - First run creates `./.env.new` from the current `./.env` and prints edit instructions.
  - After editing, rerun with the same file to apply changes and refresh the environment.
  - Add `--rebuild` to force a rebuild/restart after applying changes.

## Dev-to-Prod Image Freeze

Use this workflow when you want a fully self-contained production image for RDKit scripts and runtime tooling.

Prerequisite:
- The base core image must exist locally: `chembience/core-rdkit:${CHEMBIENCE_VERSION}` from your app `.env` (for example, run `./build` from repository root first).

```bash
./rdkit-prepare-prod
```

What the script does:
- Creates/reuses `./.env.prod` from `./.env` and forces `CHEMBIENCE_RUNTIME_MODE=prod` there.
- Builds a dedicated source-baked production image via `Dockerfile.prod`.
- Uses a clear production image name: `chembience/core-rdkit-prod-<app_name>:<tag>`.
- Runs an RDKit smoke check from the built image (`MolFromSmiles`).
- Does **not** run `rdkit-configure`, does **not** restart compose services, and does **not** mutate your active dev `.env`.

Optional flags:
- `--keep-env-prod` → reuses existing `./.env.prod`.
- `--image-tag <tag>` → release tag for the produced image.
- `--image-name <name>` → override default production image repository/name.
- `--skip-build` → skip the build step (metadata prep only).

Examples:

```bash
# Repeatable release image build
./rdkit-prepare-prod --image-tag 0.6.0-rdkit.1

# Custom production image repository/name
./rdkit-prepare-prod --image-name registry.example.com/chem/rdkit-prod --image-tag 0.6.0-rdkit.1
```

Run the produced image (example):

```bash
docker run --rm --entrypoint /opt/conda/envs/chembience/bin/python chembience/core-rdkit-prod-app:0.6.0-rdkit.1 - <<'PY'
from rdkit import Chem
print(bool(Chem.MolFromSmiles('CCO')))
PY
```

Repeatability note:
- Running the script again with the same `--image-name` and `--image-tag` rebuilds/replaces the same image tag deterministically from the current source state.
