#!/usr/bin/env bash
set -e

# jenkins user requires valid UID:GID permissions at the host level to persist data
#
# set Jenkins UID and GID values (as root)
usermod -u ${JENKINS_UID} jenkins
groupmod -g ${JENKINS_GID} jenkins
# update ownership of directories (as root)
{
  chown -R jenkins:jenkins /var/jenkins_home
  chown -R jenkins:jenkins /usr/share/jenkins/ref
} ||
{
  echo "[ERROR] Failed 'chown -R jenkins:jenkins ...' command"
}

# allow jenkins to run sudo docker (as root)
echo "jenkins ALL=(root) NOPASSWD: /usr/bin/docker" > /etc/sudoers.d/jenkins
chmod 0440 /etc/sudoers.d/jenkins

# run Jenkins (as jenkins)
sed -i "s# exec java# exec $(which java)#g" /usr/local/bin/jenkins.sh
su jenkins -c 'cd $HOME; export PATH=$PATH:$(which java); /usr/local/bin/jenkins.sh'
