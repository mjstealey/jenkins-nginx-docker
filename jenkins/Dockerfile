FROM jenkins/jenkins:lts-jdk11
MAINTAINER Michael J. Stealey <michael.j.stealey@gmail.com>

# add ability to run docker from within jenkins (docker in docker)
USER root
RUN apt-get update && apt-get install -y lsb-release sudo
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

# set default user attributes
ENV JENKINS_UID=1000
ENV JENKINS_GID=1000

# add entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# normally user would be set to jenkins, but this is handled by the docker-entrypoint script on startup
#USER jenkins
USER root

# bypass normal entrypoint and use custom one
#ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]
