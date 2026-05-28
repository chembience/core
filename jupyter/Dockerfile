ARG build_tag=latest
FROM chembience/core-rdkit:$build_tag
ARG conda_py
ARG conda_mirror
ARG app_name

LABEL maintainer="markus.sitzmann@gmail.com"

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN mkdir -p /jupyter

COPY jupyter/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
COPY .gitignore /
COPY jupyter/docker-compose.yml /jupyter/docker-compose.yml
COPY jupyter/requirements.txt /jupyter/requirements.txt
COPY jupyter/app/Dockerfile /jupyter/Dockerfile
COPY jupyter/app/requirements.txt /jupyter/app-requirements.txt
COPY jupyter/app/jupyter-init /jupyter/jupyter-init
COPY jupyter/app/jupyter-configure /jupyter/jupyter-configure
COPY jupyter/app/notebooks /jupyter/app/notebooks
COPY psql /jupyter/psql
COPY share /opt/share
COPY .env.example /jupyter/.env.example

# Do not copy the entire repository into the image; rely on bind mounts for dev

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN if grep -qE '^\s*[^#\s]' /jupyter/requirements.txt; then \
        micromamba run -n chembience python -m pip install --no-cache-dir -r /jupyter/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    micromamba run -n chembience python -m pip install -e /opt/share && \
    micromamba clean -a -y && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app
