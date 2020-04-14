#!/bin/bash

echo "Creating EC2 instance..."

# find deployment user key pair ID
#aws iam list-users >> users.yml
#N_USERS=$(yq r users.yml --collect --length Users.*.UserName)
#
#for (( USER_INDEX = 0; USER_INDEX <= $N_USERS; USER_INDEX++ ));
#do
#  USERNAME=$(yq r users.yml Users.[$USER_INDEX].UserName)
#  USER_ID=$(yq r users.yml Users.[$USER_INDEX].UserId)
#  if [ "$USERNAME" == $AWS_DEPLOYMENT_USERNAME ]
#    
#  fi
#done

#AWS_DEPLOYMENT_USERNAME=deployment@madhattertech.ca
#GITHUB_SHA=12345
#GITHUB_REPOSITORY=dontworrru

# create the key pair from SSH key 
echo "Creating key pair..."
AWS_DEPLOYMENT_PUBLIC_KEY_ID=$(aws iam list-ssh-public-keys --user-name $AWS_DEPLOYMENT_USERNAME --profile production | yq r - SSHPublicKeys.[0].SSHPublicKeyId)
aws iam get-ssh-public-key --user-name $AWS_DEPLOYMENT_USERNAME --ssh-public-key-id $AWS_DEPLOYMENT_PUBLIC_KEY_ID --encoding SSH --profile production \
  | yq r - SSHPublicKey.SSHPublicKeyBody >> ssh.pub
echo "WARNING: this may complain about a duplicate key ... this is not an issue"
aws ec2 import-key-pair --key-name $GITHUB_SHA --public-key-material fileb://$PWD/ssh.pub --profile production

# create the instance
echo "Creating instance..."
SUBNET_ID=$(yq r subnet.yml Subnet.SubnetId)
aws ec2 run-instances --image-id ami-04a25c39dc7a8aebb --count 1 --instance-type t2.micro --key-name $GITHUB_SHA --subnet $SUBNET_ID --profile production >> instance.yml
INSTANCE_ID=$(yq r instance.yml Instances.[0].InstanceId)
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production

echo "Done."
