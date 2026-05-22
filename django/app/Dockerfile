ARG build_tag=latest
ARG app_name
FROM chembience/core-django:${build_tag}

LABEL maintainer="markus.sitzmann@gmail.com"

COPY requirements.txt /opt/django/app-requirements.txt

RUN if grep -qE '^\s*[^#\s]' /opt/django/app-requirements.txt; then \
        conda run -n chembience python -m pip install --no-cache-dir -r /opt/django/app-requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping pip install"; \
    fi && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    mkdir -p /home/app/src/dbbackup

WORKDIR /home/app/src
