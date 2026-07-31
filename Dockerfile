# syntax=docker/dockerfile:1.7

FROM alpine:3.20 AS base

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apk add --no-cache \
        bash \
        bubblewrap \
        ca-certificates \
        curl \
        git \
        less \
        openssh-client \
        ripgrep \
        tini \
        zsh

RUN apk add --no-cache shadow \
    && existing_group="$(getent group "${GROUP_ID}" | cut -d: -f1)" \
    && if [ -n "${existing_group}" ]; then \
        groupmod --new-name agent "${existing_group}"; \
    else \
        groupadd --gid "${GROUP_ID}" agent; \
    fi \
    && existing_user="$(getent passwd "${USER_ID}" | cut -d: -f1)" \
    && if [ -n "${existing_user}" ]; then \
        usermod --login agent \
            --home /home/agent \
            --move-home \
            --gid "${GROUP_ID}" \
            --shell /bin/bash \
            "${existing_user}"; \
    else \
        useradd --uid "${USER_ID}" \
            --gid "${GROUP_ID}" \
            --create-home \
            --shell /bin/bash \
            agent; \
    fi \
    && mkdir -p /home/agent /workspace \
    && chown agent:agent /home/agent /workspace \
    && apk del shadow

ENV HOME=/home/agent
ENV DISABLE_AUTOUPDATER=1

WORKDIR /workspace
ENTRYPOINT ["tini", "--"]

# -----------------------------------------------------------------------------
FROM base AS codex

ARG CODEX_VERSION=latest

RUN mkdir -p /opt/codex/bin \
    && chown agent:agent /opt/codex /opt/codex/bin

ENV PATH=/opt/codex/bin:$PATH

USER agent

RUN curl --fail --silent --show-error --location \
        https://chatgpt.com/codex/install.sh \
        --output /tmp/install-codex.sh \
    && CODEX_HOME=/opt/codex \
       CODEX_INSTALL_DIR=/opt/codex/bin \
       CODEX_NON_INTERACTIVE=true \
       CODEX_RELEASE="${CODEX_VERSION}" \
           sh /tmp/install-codex.sh \
    && rm /tmp/install-codex.sh \
    && codex --version

ENV CODEX_HOME=/home/agent/.codex

CMD ["codex"]

# -----------------------------------------------------------------------------
FROM base AS claude

ARG CLAUDE_VERSION=latest

RUN mkdir -p /opt/claude \
    && chown agent:agent /opt/claude

ENV PATH=/opt/claude/.local/bin:$PATH

USER agent

RUN curl --fail --silent --show-error --location \
        https://claude.ai/install.sh \
        --output /tmp/install-claude.sh \
    && HOME=/opt/claude bash /tmp/install-claude.sh "${CLAUDE_VERSION}" \
    && rm /tmp/install-claude.sh \
    && rm -rf /opt/claude/.claude/downloads \
    && claude --version

CMD ["claude"]
