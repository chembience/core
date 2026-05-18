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
COPY django/prod /django/prod
COPY django/app/django-rdkit-test-app /django/django-rdkit-test-app/
COPY django/requirements.txt /opt/django

# Copy application code if it exists locally during build
# When running 'prod' script, this will copy the current directory (app context) into the image
# We use a conditional check to see if there's anything to copy that isn't just the core directory
COPY . /home/app/
# Ensure correct permissions for the default app user (1000)
RUN if [ -d /home/app ]; then chown -R 1000:1000 /home/app && find /home/app -type d -exec chmod 755 {} + && find /home/app -type f -exec chmod 644 {} +; fi
# Make sure scripts are executable
RUN if [ -f /home/app/psql ]; then chmod +x /home/app/psql; fi && \
    if [ -f /home/app/django-init ]; then chmod +x /home/app/django-init; fi && \
    if [ -f /home/app/django-manage-py ]; then chmod +x /home/app/django-manage-py; fi && \
    if [ -f /home/app/prod ]; then chmod +x /home/app/prod; fi

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
    conda run -n chembience python -c "import django_rdkit" && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app/appsite
