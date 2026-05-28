ARG mamba_image=mambaorg/micromamba:1.5.8
FROM ${mamba_image}

ARG conda_py
ARG rdkit_version
ARG apt_mirror
ARG conda_mirror

LABEL maintainer="markus.sitzmann@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive \
    MAMBA_ROOT_PREFIX=/opt/conda \
    CONDA_ENV=chembience \
    PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:/home/app:$PATH

# System packages (run as root inside micromamba image)
USER root
RUN if [ -n "${apt_mirror}" ]; then \
        sed -i "s|http://deb.debian.org/debian|${apt_mirror}|g" /etc/apt/sources.list || true; \
    fi && \
    printf 'Acquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-retries && \
    apt-get update && \
    apt-get -y --no-install-recommends install \
      gosu \
      postgresql-client \
      libpq5 \
      curl \
      git \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p /home/app /opt/python /opt/rdkit

COPY rdkit/requirements.txt /opt/python/requirements.txt
COPY rdkit/docker-entrypoint.sh /docker-entrypoint.sh
COPY rdkit/app/run /opt/rdkit/run
COPY rdkit/app/shell /opt/rdkit/shell
COPY rdkit/app/Dockerfile /opt/rdkit/Dockerfile
COPY rdkit/app/docker-compose.yml /opt/rdkit/docker-compose.yml
COPY rdkit/app/requirements.txt /opt/rdkit/app-requirements.txt
COPY rdkit/app/rdkit-init /opt/rdkit/rdkit-init
COPY rdkit/app/rdkit-configure /opt/rdkit/rdkit-configure
COPY rdkit/app/README.md /opt/rdkit/README.md
COPY rdkit/environment.yml /opt/rdkit/environment.yml
COPY psql /opt/rdkit/psql
COPY .env.example /opt/rdkit/.env.example
COPY share /opt/share

# Ensure editable install target is writable by non-root user
USER root
RUN chown -R mambauser:mambauser /opt/share

# Switch back to non-root user for micromamba operations (micromamba image uses 'mambauser')
USER mambauser
# Configure conda-forge channel and create env
RUN micromamba config append channels conda-forge && \
    micromamba create -y -n ${CONDA_ENV} -f /opt/rdkit/environment.yml && \
    if [ -n "${conda_py}" ]; then \
        micromamba install -y -n ${CONDA_ENV} "python=${conda_py}"; \
    fi && \
    if [ -n "${rdkit_version}" ]; then \
        micromamba install -y -n ${CONDA_ENV} "rdkit=${rdkit_version}"; \
    fi && \
    if grep -qE '^\s*[^#\s]' /opt/python/requirements.txt; then \
        micromamba run -n ${CONDA_ENV} python -m pip install --no-cache-dir -r /opt/python/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    micromamba run -n ${CONDA_ENV} python -m pip install -e /opt/share && \
    micromamba clean -a -y && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

## Ensure the runtime entrypoint runs with necessary privileges
USER root
# Make sure entrypoint is executable (line endings are LF per .gitattributes)
RUN chmod +x /docker-entrypoint.sh

