#!/bin/bash

echo "Creating users and providing SSH access..."

# get IP address of instance
IP_ADDRESS=$(yq r elastic-ip.yml PublicIp)

# create the SSH key for the new instance from the Github Secret
if test -f "$AWS_SSH_KEY_FILENAME";
then
  echo "Deployment user SSH key exists"
else
  echo "$AWS_SSH_KEY" >> $AWS_SSH_KEY_FILENAME
  sudo chmod 600 $AWS_SSH_KEY_FILENAME
fi

# add users to the instance
echo "Adding DevOps users to the instance..."
aws iam get-group --group-name DevOps --profile production >> devops-users.yml
N_USERS=$(yq r devops-users.yml --collect --length Users.*.UserName)
echo "Found $N_USERS users"
for (( USER_INDEX = 0; USER_INDEX < "$N_USERS"; USER_INDEX++ ));
do
USERNAME=$(yq r devops-users.yml Users.[$USER_INDEX].UserName)
USER_ID=$(yq r devops-users.yml Users.[$USER_INDEX].UserId)

echo "Creating user $USERNAME"

# get the user's public key
USER_PUBLIC_KEY_ID=$(aws iam list-ssh-public-keys --user-name $USERNAME --profile production | yq r - SSHPublicKeys.[0].SSHPublicKeyId)
USER_PUBLIC_KEY=$(aws iam get-ssh-public-key --user-name $USERNAME --ssh-public-key-id $USER_PUBLIC_KEY_ID --encoding SSH --profile production \
  | yq r - SSHPublicKey.SSHPublicKeyBody)

# create a user with this name
ssh -A -T -o StrictHostKeyChecking=no -i $AWS_SSH_KEY_FILENAME centos@$IP_ADDRESS <<-HERE
sudo useradd $USERNAME
sudo passwd -d $USERNAME
sudo usermod -aG wheel $USERNAME
su - $USERNAME
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
chmod -R go= ~/.ssh
chown -R $USERNAME:$USERNAME ~/.ssh
echo "$USER_PUBLIC_KEY" >> ~/.ssh/authorized_keys
HERE
done

echo "Done."
