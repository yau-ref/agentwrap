# syntax=docker/dockerfile:1.7

FROM ubuntu:latest

ARG AGENT=codex
ARG CODEX_VERSION=latest
ARG CLAUDE_VERSION=latest
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bubblewrap \
        ca-certificates \
        curl \
        git \
        less \
        openssh-client \
        tini \
        zsh \
    && rm -rf /var/lib/apt/lists/*

# Install the selected agent CLI into an immutable, system-wide location.
# CODEX_VERSION / CLAUDE_VERSION can be set at build time for reproducibility.
RUN <<'EOF'
set -eu
case "$AGENT" in
    codex)
        curl --fail --silent --show-error --location \
            https://chatgpt.com/codex/install.sh \
            --output /tmp/install-codex.sh
        CODEX_HOME=/opt/codex \
        CODEX_INSTALL_DIR=/usr/local/bin \
        CODEX_NON_INTERACTIVE=true \
        CODEX_RELEASE="${CODEX_VERSION}" \
            sh /tmp/install-codex.sh
        rm /tmp/install-codex.sh
        codex --version
        ;;
    claude)
        curl --fail --silent --show-error --location \
            https://claude.ai/install.sh \
            --output /tmp/install-claude.sh
        HOME=/opt/claude bash /tmp/install-claude.sh "${CLAUDE_VERSION}"
        rm /tmp/install-claude.sh
        resolved="$(readlink -f /opt/claude/.local/bin/claude)"
        ln -s "${resolved}" /usr/local/bin/claude
        rm -rf /opt/claude/.claude/downloads
        claude --version
        ;;
    *)
        echo "Unknown AGENT: ${AGENT} (expected 'codex' or 'claude')" >&2
        exit 1
        ;;
esac
EOF

RUN existing_group="$(getent group "${GROUP_ID}" | cut -d: -f1)" \
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
    && chown agent:agent /home/agent /workspace

ENV DEBIAN_FRONTEND=
ENV HOME=/home/agent
ENV CODEX_HOME=/home/agent/.codex
ENV DISABLE_AUTOUPDATER=1
ENV AGENT=${AGENT}

USER agent
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/sh", "-c", "exec \"$AGENT\""]
