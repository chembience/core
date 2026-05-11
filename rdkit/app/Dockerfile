ARG build_tag=latest
ARG app_name_block
FROM chembience/core-rdkit:${build_tag}

LABEL maintainer="markus.sitzmann@gmail.com"

COPY requirements.txt /opt/python/app-requirements.txt

RUN if grep -qE '^\s*[^#\s]' /opt/python/app-requirements.txt; then \
        conda install -n chembience --yes --file /opt/python/app-requirements.txt; \
    else \
        echo "requirements.txt is empty; skipping conda install"; \
    fi && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app
