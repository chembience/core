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
COPY fastapi/docker-compose.yml /fastapi/docker-compose.yml
COPY fastapi/app/docker-compose.override.yml /fastapi/docker-compose.override.yml
COPY fastapi/app/Dockerfile /fastapi/Dockerfile
COPY fastapi/app/requirements.txt /fastapi/requirements.txt
COPY fastapi/app/README.md /fastapi/README.md
COPY fastapi/app/db_backup /fastapi/db_backup
COPY fastapi/app/db_restore /fastapi/db_restore
COPY fastapi/app/db_cleanup /fastapi/db_cleanup
COPY fastapi/app/fastapi-init /fastapi/fastapi-init
COPY fastapi/app/src /fastapi/src
COPY psql /fastapi/psql
COPY share /opt/share
COPY .env.example /fastapi/.env.example
COPY fastapi/requirements.txt /opt/fastapi

# Do not bake the project source into the image — rely on bind mounts in dev
# and a separate builder/publisher for production images.

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN conda config --system --set remote_read_timeout_secs 600.0 && \
    if [ -n "${conda_mirror}" ]; then \
        conda config --system --set channel_alias "${conda_mirror}"; \
    fi && \
    if grep -qE '^\s*[^#\s]' /opt/fastapi/requirements.txt; then \
        conda run -n chembience python -m pip install --no-cache-dir -r /opt/fastapi/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    conda run -n chembience python -m pip install -e /opt/share && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app/src
