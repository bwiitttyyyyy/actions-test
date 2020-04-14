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
echo "pwd $PWD"
echo "cwd $CWD"
exit 1
# create the security group
echo "Creating EC2 instance security group..."
VPC_ID=$(yq r vpc.yml Vpc.VpcId)
aws ec2 create-security-group --group-name ec2-$GITHUB_SHA --description "Security group for EC2 instance of application at commit $GITHUB_SHA" --vpc-id $VPC_ID --profile production >> ec2-security-group.yml
EC2_SECURITY_GROUP_ID=$(yq r ec2-security-group.yml GroupId)
aws ec2 create-tags --resources $EC2_SECURITY_GROUP_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Enabling SSH access..."
aws ec2 authorize-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --profile production
echo "Enabling HTTP ingress access..."
aws ec2 authorize-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --profile production
aws ec2 authorize-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges='[{CidrIpv6=::/0}]' --profile production
echo "Enabling HTTPS ingress access..."
aws ec2 authorize-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --profile production
aws ec2 authorize-security-group-ingress --group-id $EC2_SECURITY_GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,Ipv6Ranges='[{CidrIpv6=::/0}]' --profile production
echo "Created EC2 security group with ID $EC2_SECURITY_GROUP_ID"

# create the key pair from SSH key 
echo "Creating key pair..."
AWS_DEPLOYMENT_PUBLIC_KEY_ID=$(aws iam list-ssh-public-keys --user-name $AWS_DEPLOYMENT_USERNAME --profile production | yq r - SSHPublicKeys.[0].SSHPublicKeyId)
aws iam get-ssh-public-key --user-name $AWS_DEPLOYMENT_USERNAME --ssh-public-key-id $AWS_DEPLOYMENT_PUBLIC_KEY_ID --encoding SSH --profile production \
  | yq r - SSHPublicKey.SSHPublicKeyBody >> ssh.pub
echo "WARNING: this may complain about a duplicate key ... this is not an issue"
aws ec2 import-key-pair --key-name $GITHUB_SHA --public-key-material fileb://$PWD/ssh.pub --profile production
echo "Created key pair with name $GITHUB_SHA"
# create the instance
echo "Creating instance..."
SUBNET_ID=$(yq r subnet.yml Subnet.SubnetId)
aws ec2 run-instances --image-id ami-04a25c39dc7a8aebb --count 1 --instance-type t2.micro --key-name $GITHUB_SHA --subnet $SUBNET_ID --region ca-central-1 --profile production >> instance.yml
INSTANCE_ID=$(yq r instance.yml Instances.[0].InstanceId)
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created instance with ID $INSTANCE_ID"

# wait for instance become of state "running"
echo "Waiting for instance $INSTANCE_ID to be up and running..."
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --profile production >> ec2-instance-status.yml
EC2_INSTANCE_STATUS_CODE=$(yq r ec2-instance-status.yml InstanceStatuses.[0].InstanceState.Code)
EC2_INSTANCE_STATUS_NAME=$(yq r ec2-instance-status.yml InstanceStatuses.[0].InstanceState.Name)
while [ "$EC2_INSTANCE_STATUS_CODE" != "16" ]
do
  [ -z "$EC2_INSTANCE_STATUS_NAME" ] && echo "Status: pending" || echo  "Status: $EC2_INSTANCE_STATUS_NAME"
  sleep 5s
  rm ec2-instance-status.yml
  aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --profile production >> ec2-instance-status.yml
  EC2_INSTANCE_STATUS_CODE=$(yq r ec2-instance-status.yml InstanceStatuses.[0].InstanceState.Code)
  EC2_INSTANCE_STATUS_NAME=$(yq r ec2-instance-status.yml InstanceStatuses.[0].InstanceState.Name)
done
echo "Instance is now running"

# create Elastic IP address
echo "Creating Elastic IP address..."
aws ec2 allocate-address --domain vpc --profile production >> elastic-ip.yml
ELASTIC_IP_ALLOCATION_ID=$(yq r elastic-ip.yml AllocationId)
IP_ADDRESS=$(yq r elastic-ip.yml PublicIp)
echo "Associating IP..."
aws ec2 associate-address --allocation-id $ELASTIC_IP_ALLOCATION_ID --instance-id $INSTANCE_ID --profile production
echo "Created Elastic IP address $IP_ADDRESS"

# will neeeeeed to get all of the users' ssh keys here before we log in

# ssh into the instance
echo "Entering instance..."
echo "$AWS_SSH_KEY" >> aws_ssh_key
cat ../centos/os-setup.sh | ssh -T -i aws_ssh_key centos@$IP_ADDRESS

echo "Done."
