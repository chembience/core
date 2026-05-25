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

# Copy application code if it exists locally during build
COPY . /home/app/

# Ensure correct permissions for the default app user (1000)
RUN if [ -d /home/app ]; then chown -R 1000:1000 /home/app && find /home/app -type d -exec chmod 755 {} + && find /home/app -type f -exec chmod 644 {} +; fi
# Make sure scripts are executable and files have correct permissions
RUN if [ -f /home/app/psql ]; then chmod +x /home/app/psql; fi && \
    if [ -f /home/app/jupyter-init ]; then chmod +x /home/app/jupyter-init; fi && \
    if [ -f /home/app/Dockerfile ]; then chmod 644 /home/app/Dockerfile; fi && \
    if [ -f /home/app/app-requirements.txt ]; then chmod 644 /home/app/app-requirements.txt; fi

ENV PATH=/opt/conda/envs/chembience/bin:/opt/conda/bin:$PATH

RUN conda config --system --set remote_read_timeout_secs 600.0 && \
    if [ -n "${conda_mirror}" ]; then \
        conda config --system --set channel_alias "${conda_mirror}"; \
    fi && \
    if grep -qE '^\s*[^#\s]' /jupyter/requirements.txt; then \
        conda run -n chembience python -m pip install --no-cache-dir -r /jupyter/requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    conda run -n chembience python -m pip install -e /opt/share && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app
