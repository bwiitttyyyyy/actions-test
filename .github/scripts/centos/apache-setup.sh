#!/bin/bash

echo "Running Apache setup..."

# get the IP address of the instance
IP_ADDRESS=$(yq r elastic-ip.yml PublicIp)

# get deployment config
HOSTNAME=$(yq r deployment.yml apache.hostname)
DOCUMENT_ROOT=$(yq r deployment.yml apache.document_root)

# get the parent dir of the document root
IFS='/' read -r -a array <<< "$DOCUMENT_ROOT"
PATH_ARRAY_SHORTENED="${array[@]:0:PATH_LEN-1}"
function join_by { local IFS="$1"; shift; echo "$*"; }
DOCUMENT_ROOT_PARENT="/$(join_by / $PATH_ARRAY_SHORTENED)"

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

# copy the default Apache site configurations to the instance
echo "Copying the site's default Apache config to the instance..."
sed "s/[[HOSTNAME]]/$HOSTNAME/g" ./.github/resources/centos/site.conf 
sed "s/[[DOCUMENT_ROOT]]/$DOCUMENT_ROOT/g" ./.github/resources/centos/site.conf 
sed "s/[[DOCUMENT_ROOT_PARENT]]/$DOCUMENT_ROOT_PARENT/g" ./.github/resources/centos/site.conf 
scp -i $AWS_SSH_KEY_FILENAME ./.github/resources/centos/site.conf centos@$IP_ADDRESS:/etc/httpd/conf.d/$REPOSITORY.conf


# copy the default Apache SSL configurations to the instance
# NOTE: we are copying to the 'wrong' directory first to avoid Apache from trying to serve an SSL site 
# that does not have yet the proper certificates generated for it
echo "Copying the site's default Apache SSL config to the instance..."
sed "s/[[HOSTNAME]]/$HOSTNAME/g" ./.github/resources/centos/ssl.conf 
sed "s/[[DOCUMENT_ROOT]]/$DOCUMENT_ROOT/g" ./.github/resources/centos/ssl.conf 
scp -i $AWS_SSH_KEY_FILENAME ./.github/resources/centos/ssl.conf centos@$IP_ADDRESS:/etc/httpd/ssl.conf

# set up apache
echo "SSH-ing into instance and setting up Apache..."
ssh -A -T -o StrictHostKeyChecking=no -i $AWS_SSH_KEY_FILENAME centos@$IP_ADDRESS <<-HERE

# generate SSL certificates
sudo certbot certonly --apache --non-interactive --domain $HOSTNAME --domain www.$HOSTNAME

# set up certificate autorenewal
echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q" | sudo tee -a /etc/crontab > /dev/null

# copy the Apache SSL config to the correct place now that the certs have been generated
sudo mv /etc/httpd/ssl.conf /etc/httpd/conf.d/ssl./conf

# restart Apache
systemctl restart httpd.service

HERE

echo "Done."
