#!/bin/bash

# get the github repo name without the user
REPOSITORY=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)

# create the security group
echo "Creating RDS security group..."
VPC_ID=$(yq r vpc.yml Vpc.VpcId)
aws ec2 create-security-group \
  --group-name rds-$GITHUB_SHA \
  --description "Security groupd for the RDS VPC" \
  --vpc-id $VPC_ID \
  --profile production \
  >> rds-security-group.yml
RDS_SECURITY_GROUP_ID=$(yq r rds-security-group.yml GroupId)
aws ec2 create-tags \
  --resources $RDS_SECURITY_GROUP_ID \
  --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY \
  --profile production

echo "Adding ingress MySQL access..."
EC2_SECURITY_GROUP_ID=$(yq r ec2-security-group.yml GroupId)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SECURITY_GROUP_ID \
  --source-group $EC2_SECURITY_GROUP_ID \
  --protocol all \
  --port 3306 \
  --profile production
echo "Created RDS security group with ID $RDS_SECURITY_GROUP_ID"

echo "Creating DB cluster..."
PRIVATE_SUBNET_GROUP_ID=$(yq r private-subnet-group.yml DBSubnetGroup.DBSubnetGroupName)
aws rds create-db-cluster \
  --db-cluster-identifier $REPOSITORY-cluster \
  --engine aurora \
  --engine-version 5.6.10a \
  --master-username $REPOSITORY \
  --master-user-password $REPOSITORY \
  --db-subnet-group-name $PRIVATE_SUBNET_GROUP_ID \
  --vpc-security-group-ids $RDS_SECURITY_GROUP_ID \
  --port 3306 \
  --profile production \
  >> db-cluster.yml
DB_CLUSTER_ID=$(yq r db-cluster.yml DBCluster.DBClusterIdentifier)

aws rds create-db-instance \
  --db-instance-identifier  $REPOSITORY \
  --db-cluster-identifier $DB_CLUSTER_ID \
  --engine aurora \
  --db-instance-class db.r5.large \
  --storage-encrypted \
  --profile production

echo "Done."
