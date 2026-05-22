ARG conda_package=condaforge/miniforge3
ARG conda_tag=latest
FROM ${conda_package}:${conda_tag}

ARG conda_py
ARG rdkit_version
ARG apt_mirror
ARG conda_mirror

LABEL maintainer="markus.sitzmann@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive

RUN if [ -n "${apt_mirror}" ]; then \
        sed -i "s|http://archive.ubuntu.com/ubuntu/|${apt_mirror}|g" /etc/apt/sources.list && \
        sed -i "s|http://security.ubuntu.com/ubuntu/|${apt_mirror}|g" /etc/apt/sources.list; \
    fi && \
    printf 'Acquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-retries && \
    apt-get --allow-releaseinfo-change update && \
    apt-get -y --no-install-recommends install \
      gosu \
      postgresql-client \
      libpq-dev \
      build-essential \
      python3-dev \
      telnet \
      curl && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/app /opt/python /opt/rdkit

ENV CONDA_ENV=chembience
ENV PATH=/opt/conda/envs/${CONDA_ENV}/bin:/opt/conda/bin:/home/app:$PATH

COPY rdkit/requirements.txt /opt/python/requirements.txt
COPY rdkit/docker-entrypoint.sh /docker-entrypoint.sh
COPY rdkit/app/run /opt/rdkit/run
COPY rdkit/app/shell /opt/rdkit/shell
COPY rdkit/app/Dockerfile /opt/rdkit/Dockerfile
COPY rdkit/app/docker-compose.yml /opt/rdkit/docker-compose.yml
COPY rdkit/app/requirements.txt /opt/rdkit/app-requirements.txt
COPY rdkit/app/rdkit-init /opt/rdkit/rdkit-init
COPY rdkit/app/README.md /opt/rdkit/README.md
COPY psql /opt/rdkit/psql
COPY .env.example /opt/rdkit/.env.example
COPY share /opt/share

RUN conda config --system --set remote_read_timeout_secs 600.0 && \
    if [ -n "${conda_mirror}" ]; then \
        conda config --system --set channel_alias "${conda_mirror}"; \
    fi && \
    conda config --system --remove-key channels || true && \
    conda config --system --add channels conda-forge && \
    conda config --system --set channel_priority strict && \
    conda config --system --set show_channel_urls yes && \
    conda create --verbose --yes -n ${CONDA_ENV} python=${conda_py} && \
    if [ -n "${rdkit_version}" ]; then \
        conda run -n ${CONDA_ENV} conda install --yes "rdkit=${rdkit_version}"; \
    else \
        conda run -n ${CONDA_ENV} conda install --yes rdkit; \
    fi && \
    if grep -qE '^\s*[^#\s]' /opt/python/requirements.txt; then \
        conda run -n ${CONDA_ENV} python -m pip install --no-cache-dir -r /opt/python/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    conda run -n ${CONDA_ENV} python -m pip install -e /opt/share && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

