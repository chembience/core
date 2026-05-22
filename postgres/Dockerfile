ARG conda_package=condaforge/miniforge3
ARG conda_tag=latest
FROM $conda_package:$conda_tag
ARG conda_py
ARG apt_mirror
ARG conda_mirror
ARG CHEMBIENCE_UID=1000
ARG CHEMBIENCE_GID=1000

LABEL maintainer="markussitzmann@gmail.com "

RUN if [ -n "${apt_mirror}" ]; then \
        sed -i "s|http://archive.ubuntu.com/ubuntu/|${apt_mirror}|g" /etc/apt/sources.list && \
        sed -i "s|http://security.ubuntu.com/ubuntu/|${apt_mirror}|g" /etc/apt/sources.list; \
    fi && \
    printf 'Acquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-retries && \
    apt-get --allow-releaseinfo-change update && \
    apt-get -y --no-install-recommends install gosu joe postgresql-client

RUN mkdir -p /home/postgres /opt/python

RUN mkdir -p /home/postgres/postgres_data && \
    chown -R ${CHEMBIENCE_UID}:${CHEMBIENCE_GID} /home/postgres


COPY postgres/docker-entrypoint.sh /
COPY postgres/pg_hba.conf /
COPY postgres/postgresql.conf /

RUN conda config --system --set remote_read_timeout_secs 600.0 && \
    if [ -n "${conda_mirror}" ]; then \
        conda config --system --set channel_alias "${conda_mirror}"; \
    fi && \
    conda config --system --remove-key channels || true && \
    conda config --system --add channels conda-forge && \
    conda config --system --set channel_priority strict && \
    conda config --system --set show_channel_urls yes && \
    conda create --verbose --yes -n chembience && \
    conda run -n chembience conda install --yes rdkit-postgresql && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

