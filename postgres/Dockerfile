ARG conda_package=condaforge/miniforge3
ARG conda_tag=latest
FROM $conda_package:$conda_tag
ARG conda_py

LABEL maintainer="markussitzmann@gmail.com "

RUN apt-get --allow-releaseinfo-change update && \
    apt-get -y --no-install-recommends install gosu joe postgresql-client

RUN mkdir -p /home/postgres /opt/python

RUN mkdir -p /home/postgres/postgres_data && \
    chown -R ${CHEMBIENCE_UID}:${CHEMBIENCE_GID} /home/postgres

ENV PATH=/opt/conda/bin:$PATH

COPY docker-entrypoint.sh /
COPY pg_hba.conf /
COPY postgresql.conf /

RUN conda config --system --remove-key channels || true && \
    conda config --system --add channels conda-forge && \
    conda config --system --set channel_priority strict && \
    conda config --system --set show_channel_urls yes && \
    conda create --verbose --yes -n chembience && \
    conda run -n chembience conda install --yes rdkit-postgresql && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

