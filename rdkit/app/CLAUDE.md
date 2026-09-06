# RDKit App Development Guide

Run commands from this generated app directory.

- Start and verify: `docker compose up -d && ./rdkit-init`
- Run a script: `./run your_script.py`
- Interactive shell: `./shell`
- Database shell: `./psql`
- Add script dependencies to `requirements.txt`

Do not commit `.env` or production secrets. For Docker Compose production read
`PROD/README.md`; for Kubernetes/GHCR production read `PROD/k8s/README.md` and
use `./rdkit-prepare-prod --target ghcr-k8s`.
