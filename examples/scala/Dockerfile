ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG SCALA_VERSION=3.9.0
ARG SBT_VERSION=1.13.1

USER root
RUN apk add --no-cache openjdk21-jdk \
    && curl -fL "https://github.com/scala/scala3/releases/download/${SCALA_VERSION}/scala3-${SCALA_VERSION}.tar.gz" \
        | tar -xz -C /opt \
    && mv "/opt/scala3-${SCALA_VERSION}" /opt/scala3 \
    && ln -s /opt/scala3/bin/* /usr/local/bin/ \
    && curl -fL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
        | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/* /usr/local/bin/
USER agent
