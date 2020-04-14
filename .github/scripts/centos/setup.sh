#!/bin/bash

echo "Setting up CentOS..."

# get IP address of instance
IP_ADDRESS=$(yq r elastic-ip.yml ElasticIp)

# create the SSH key for the new instance from the github secret
if test -f "$AWS_SSH_KEY_FILENAME";
then
  echo "Deployment user SSH key exists"
else
  echo "$AWS_SSH_KEY" >> $AWS_SSH_KEY_FILENAME
  sudo chmod 600 $AWS_SSH_KEY_FILENAME
fi

# try something

ssh -A -T -o StrictHostKeyChecking=no -i $AWS_SSH_KEY_FILENAME centos@$IP_ADDRESS << '
  hostname
' 2>&1

echo "Done."
