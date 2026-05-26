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
