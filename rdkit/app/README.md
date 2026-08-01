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

## Dev-to-Prod Promotion

Use this workflow when your project is ready to run with `CHEMBIENCE_RUNTIME_MODE=prod`.

1. Finalize your RDKit scripts and dependencies in `dev` mode.
2. Run:

```bash
./rdkit-prepare-prod
```

What the script does:
- Creates a fresh `./.env.prod` from `./.env`.
- Sets `CHEMBIENCE_RUNTIME_MODE=prod` in `./.env.prod`.
- Applies it through `./rdkit-configure ./.env.prod`.
- Runs compose validation and an RDKit smoke check (`MolFromSmiles`).

Optional flags:
- `--rebuild` → passes through to `rdkit-configure --rebuild`.
- `--keep-env-prod` → reuses existing `./.env.prod`.

Recommended post-promotion checks:

```bash
docker compose --env-file ./.env ps
./run your_script.py
docker compose --env-file ./.env run --rm rdkit python - <<'PY'
from rdkit import Chem
print(bool(Chem.MolFromSmiles('CCO')))
PY
```

Current Phase 2 caveats:
- In `prod`, RDKit skips app-context bootstrap (`run`, `shell`, `rdkit-init`, `.env` generation).
- Ensure these files already exist in your app directory before switching to `prod`.
