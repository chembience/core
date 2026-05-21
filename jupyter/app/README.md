# Chembience JupyterLab Service

This service provides a JupyterLab environment integrated with RDKit and pre-configured to connect to the Chembience PostgreSQL database.

## Features

- **JupyterLab**: Modern web-based interface for notebooks.
- **RDKit**: Chemical informatics and machine learning software.
- **SQLAlchemy & Razi**: Database toolkit and RDKit-Postgres integration for chemical data queries.
- **Pre-configured Connectivity**: Automatically connects to the `postgres` service using environment variables.

## Getting Started

To start the JupyterLab service along with the rest of the Chembience stack:

```bash
docker compose up
```

By default, JupyterLab will be available at: [http://localhost:8888](http://localhost:8888)

(Note: The port can be changed via `JUPYTER_CONNECTION_PORT` in your `.env` file.)

## Directory Structure

- `notebooks/`: Default directory for your Jupyter notebooks.
  - `check_env.py`: A script to verify that RDKit and the database connection are working correctly.
- `psql`: Helper script for accessing the PostgreSQL database directly.
- `jupyter-init`: Script to verify the environment and start the service if needed.
- `requirements.txt`: Python dependencies installed in this environment.

## Verifying the Environment

You can verify that everything is correctly set up by running the `check_env.py` script from within JupyterLab terminal or as a notebook cell:

```python
%run notebooks/check_env.py
```

Or via docker exec:

```bash
docker compose exec jupyter python notebooks/check_env.py
```

## Database Access

The environment is pre-configured with the following variables for database access (matching the `postgres` service):
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_NAME`
- `POSTGRES_HOST`
- `POSTGRES_PORT` (Internal port 5432)
