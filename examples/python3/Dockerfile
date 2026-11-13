ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root
RUN apk add --no-cache \
        build-base \
        py3-pip \
        python3 \
        python3-dev \
        uv
USER agent

# The uv cache and /workspace are on different filesystems, so uv can't
# hardlink into .venv. Copy instead of warning about it on every install.
ENV UV_LINK_MODE=copy
