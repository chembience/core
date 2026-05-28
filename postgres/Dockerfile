ARG mamba_image=mambaorg/micromamba:1.5.8
FROM ${mamba_image}
ARG conda_py
ARG apt_mirror
ARG conda_mirror
ARG CHEMBIENCE_UID=1000
ARG CHEMBIENCE_GID=1000

LABEL maintainer="markussitzmann@gmail.com "

USER root
RUN if [ -n "${apt_mirror}" ]; then \
        sed -i "s|http://deb.debian.org/debian|${apt_mirror}|g" /etc/apt/sources.list || true; \
    fi && \
    printf 'Acquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-retries && \
    apt-get update && \
    apt-get -y --no-install-recommends install gosu postgresql-client && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p /home/postgres /opt/python /opt/postgres

RUN mkdir -p /home/postgres/postgres_data && \
    chown -R ${CHEMBIENCE_UID}:${CHEMBIENCE_GID} /home/postgres


COPY postgres/docker-entrypoint.sh /
COPY postgres/pg_hba.conf /
COPY postgres/postgresql.conf /
COPY postgres/environment.yml /opt/postgres/environment.yml

# Switch back to non-root for micromamba operations (micromamba image uses 'mambauser')
USER mambauser
ENV MAMBA_ROOT_PREFIX=/opt/conda
RUN micromamba config append channels conda-forge && \
    micromamba create -y -n chembience -f /opt/postgres/environment.yml && \
    if [ -n "${conda_py}" ]; then \
        micromamba install -y -n chembience "python=${conda_py}"; \
    fi && \
    micromamba clean -a -y && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

# Ensure the runtime entrypoint has the privileges it needs to prepare the data dir
USER root
# Make sure entrypoint is executable (can be lost on some checkouts)
RUN chmod +x /docker-entrypoint.sh

