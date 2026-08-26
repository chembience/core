ARG build_tag=latest
FROM chembience/core-rdkit:$build_tag
ARG conda_py
ARG conda_mirror
ARG app_name

LABEL maintainer="markus.sitzmann@gmail.com"

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN mkdir -p /opt/fastapi

COPY fastapi/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
COPY .gitignore /
COPY .dockerignore /
COPY fastapi/docker-compose.yml /fastapi/docker-compose.yml
COPY fastapi/app/docker-compose.override.yml /fastapi/docker-compose.override.yml
COPY fastapi/app/Dockerfile /fastapi/Dockerfile
COPY fastapi/app/Dockerfile.prod /fastapi/Dockerfile.prod
COPY fastapi/app/PROD /fastapi/PROD
COPY prod-tools /fastapi/prod-tools
COPY fastapi/app/requirements.txt /fastapi/requirements.txt
COPY fastapi/app/README.md /fastapi/README.md
COPY fastapi/app/db-backup /fastapi/db-backup
COPY fastapi/app/db-restore /fastapi/db-restore
COPY fastapi/app/db-cleanup /fastapi/db-cleanup
COPY fastapi/app/fastapi-init /fastapi/fastapi-init
COPY fastapi/app/fastapi-migrate /fastapi/fastapi-migrate
COPY fastapi/app/fastapi-makemigrations /fastapi/fastapi-makemigrations
COPY fastapi/app/fastapi-configure /fastapi/fastapi-configure
COPY fastapi/app/fastapi-prepare-prod /fastapi/fastapi-prepare-prod
COPY psql /fastapi/psql
COPY VERSION /opt/VERSION
COPY share /opt/share
COPY .env.template /fastapi/.env.template
COPY fastapi/requirements.txt /opt/fastapi

# Do not bake the project source into the image — rely on bind mounts in dev
# and a separate builder/publisher for production images.

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN if grep -qE '^\s*[^#\s]' /opt/fastapi/requirements.txt; then \
        micromamba run -n chembience python -m pip install --no-cache-dir -r /opt/fastapi/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    micromamba run -n chembience python -m pip install -e /opt/share --config-settings editable-mode=compat && \
    micromamba clean -a -y && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

COPY fastapi/app/src /fastapi/src

WORKDIR /home/app/src
