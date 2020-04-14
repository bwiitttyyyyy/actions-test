#!/bin/bash

echo "Setting up CentOS..."

# get IP address of instance
IP_ADDRESS=$(yq r elastic-ip.yml PublicIp)

# get the github repo name without the user
REPOSITORY=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)

# create the SSH key for the new instance from the github secret
if test -f "$AWS_SSH_KEY_FILENAME";
then
  echo "Deployment user SSH key exists"
else
  echo "$AWS_SSH_KEY" >> $AWS_SSH_KEY_FILENAME
  sudo chmod 600 $AWS_SSH_KEY_FILENAME
fi

# try something

ssh -A -T -o StrictHostKeyChecking=no -i $AWS_SSH_KEY_FILENAME centos@$IP_ADDRESS <<-HERE
sudo hostnamectl set-hostname $REPOSITORY
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sudo shutdown -r now
HERE

echo "Done."
