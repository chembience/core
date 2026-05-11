ARG build_tag=latest
FROM chembience/core-rdkit:$build_tag
ARG conda_py
ARG conda_mirror
ARG app_name_block

LABEL maintainer="markus.sitzmann@gmail.com"

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN mkdir -p /opt/django

COPY django/docker-entrypoint.sh /
COPY django/django-init /django/django-init
COPY django/django-manage-py /django/django-manage-py
COPY .gitignore /
COPY django/docker-compose.yml /django/docker-compose.yml
COPY django/app/Dockerfile /django/Dockerfile
COPY django/app/requirements.txt /django/requirements.txt
COPY psql /django/psql
COPY django/requirements.txt /opt/django

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN conda config --system --set remote_read_timeout_secs 600.0 && \
    if [ -n "${conda_mirror}" ]; then \
        conda config --system --set channel_alias "${conda_mirror}"; \
    fi && \
    conda install -n chembience --yes --file /opt/django/requirements.txt && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app/appsite
