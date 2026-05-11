ARG build_tag=latest
ARG app_name_block
FROM chembience/core-django:${build_tag}

LABEL maintainer="markus.sitzmann@gmail.com"

COPY requirements.txt /opt/django/app-requirements.txt

RUN conda install -n chembience --yes --file /opt/django/app-requirements.txt && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete

WORKDIR /home/app/appsite
