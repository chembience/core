ARG build_tag=latest
FROM chembience/rdkit:$build_tag
ARG conda_py

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
COPY django/Dockerfile /django/Dockerfile
COPY psql /django/psql
COPY django/requirements.txt /opt/django

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN conda install -n chembience --yes --file /opt/django/requirements.txt && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app/appsite
