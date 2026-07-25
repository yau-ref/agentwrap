# syntax=docker/dockerfile:1.7

FROM ubuntu:latest

ARG CODEX_VERSION=latest
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        less \
        openssh-client \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Install the standalone Codex release into an immutable, system-wide location.
# CODEX_VERSION can be set to a specific release at build time for reproducibility.
RUN curl --fail --silent --show-error --location \
        https://chatgpt.com/codex/install.sh \
        --output /tmp/install-codex.sh \
    && CODEX_HOME=/opt/codex \
       CODEX_INSTALL_DIR=/usr/local/bin \
       CODEX_NON_INTERACTIVE=true \
       CODEX_RELEASE="${CODEX_VERSION}" \
       sh /tmp/install-codex.sh \
    && rm /tmp/install-codex.sh \
    && codex --version

RUN existing_group="$(getent group "${GROUP_ID}" | cut -d: -f1)" \
    && if [ -n "${existing_group}" ]; then \
        groupmod --new-name codex "${existing_group}"; \
    else \
        groupadd --gid "${GROUP_ID}" codex; \
    fi \
    && existing_user="$(getent passwd "${USER_ID}" | cut -d: -f1)" \
    && if [ -n "${existing_user}" ]; then \
        usermod --login codex \
            --home /home/codex \
            --move-home \
            --gid "${GROUP_ID}" \
            --shell /bin/bash \
            "${existing_user}"; \
    else \
        useradd --uid "${USER_ID}" \
            --gid "${GROUP_ID}" \
            --create-home \
            --shell /bin/bash \
            codex; \
    fi \
    && mkdir -p /home/codex /workspace \
    && chown codex:codex /home/codex /workspace

ENV DEBIAN_FRONTEND=
ENV HOME=/home/codex
ENV CODEX_HOME=/home/codex/.codex

USER codex
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["codex"]
