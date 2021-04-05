# options: latest, custom (default=latest)
ARG BUILDER_TAG=latest
# options: valid version from "$ apt-cache madison docker-ce"
ARG CUSTOM_VERSION=5:20.10.5~3-0~debian-buster

FROM jenkins/jenkins:lts AS base
MAINTAINER Michael J. Stealey <michael.j.stealey@gmail.com>

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

# set default user attributes
ENV UID_JENKINS=1000
ENV GID_JENKINS=1000

# add ability to run docker from within jenkins (docker in docker)
USER root
RUN apt-get update && apt-get -y install \
    sudo \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

FROM base as build-version-latest
RUN apt-get update && apt-get -y install \
    docker-ce \
    docker-ce-cli \
    containerd.io

FROM base as build-version-custom
# set docker version (match the host version) and set java opts
ARG CUSTOM_VERSION
RUN apt-get update && apt-get -y install \
    docker-ce=${CUSTOM_VERSION} \
    docker-ce-cli=${CUSTOM_VERSION} \
    containerd.io

FROM build-version-${BUILDER_TAG} as final

# add entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# normally user would be set to jenkins, but this is handled by the docker-entrypoint script on startup
#USER jenkins

ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]
