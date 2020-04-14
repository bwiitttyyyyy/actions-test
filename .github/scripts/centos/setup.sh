#!/bin/bash

echo "Setting up CentOS..."

# get IP address of instance
IP_ADDRESS=$(yq r elastic-ip.yml PublicIp)

# get the github repo name without the user
REPOSITORY=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)
echo "REPO: $REPOSITORY"

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
# set hostname
echo "Setting hostname..."
sudo hostnamectl set-hostname $REPOSITORY

# install PHP 7.3
echo "Installing PHP 7.3..."
sudo yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm 
sudo yum -y install epel-release yum-utils
sudo yum-config-manager --disable remi-php54
sudo yum-config-manager --enable remi-php73
sudo yum -y install php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmath php-json
php -v

# install Apache
echo "Installing Apache..."
sudo yum update httpd
sudo yum install httpd
sudo systemctl start httpd
sudo systemctl status httpd

# install VIM - this is a convenience
echo "Installing VIM..."
sudo yum install vim-enhanced -y

# install Certbot
echo "Installing Certbot..."
yum -y install epel-release
yum -y install certbot python-certbot-apache

# disable SELinux 
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sudo shutdown -r now
HERE

echo "Done."
