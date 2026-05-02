ARG conda_package=condaforge/miniforge3
ARG conda_tag=latest
FROM ${conda_package}:${conda_tag}

ARG conda_py
ARG rdkit_version

LABEL maintainer="markus.sitzmann@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get --allow-releaseinfo-change update && \
    apt-get -y --no-install-recommends install \
      gosu \
      postgresql-client \
      telnet \
      curl && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/app /opt/python

ENV CONDA_ENV=chembience
ENV PATH=/opt/conda/envs/${CONDA_ENV}/bin:/opt/conda/bin:/home/app:$PATH

COPY requirements.txt /opt/python/
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN conda config --system --remove-key channels || true && \
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
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

