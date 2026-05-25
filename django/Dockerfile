ARG build_tag=latest
FROM chembience/core-rdkit:$build_tag
ARG conda_py
ARG conda_mirror
ARG app_name

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
COPY django/app/README.md /django/README.md
COPY django/psql /django/psql
COPY django/app/django-rdkit-test-app /django/django-rdkit-test-app/
COPY share /opt/share
COPY .env.example /django/.env.example
COPY django/requirements.txt /opt/django

# Do not bake the project source into the image — rely on bind mounts in dev
# and a separate builder/publisher for production images.

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN conda config --system --set remote_read_timeout_secs 600.0 && \
    if [ -n "${conda_mirror}" ]; then \
        conda config --system --set channel_alias "${conda_mirror}"; \
    fi && \
    if grep -qE '^\s*[^#\s]' /opt/django/requirements.txt; then \
        conda run -n chembience python -m pip install --no-cache-dir -r /opt/django/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    conda run -n chembience python -m pip install -e /opt/share && \
    conda run -n chembience python -c "import django_rdkit" && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app/src
