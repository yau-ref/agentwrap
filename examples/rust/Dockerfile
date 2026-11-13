ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root
RUN apk add --no-cache \
        build-base \
        cargo \
        openssl-dev \
        pkgconfig \
        rust \
        rust-clippy \
        rustfmt
USER agent
