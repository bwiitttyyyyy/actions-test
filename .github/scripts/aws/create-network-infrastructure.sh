#!/bin/bash

REPOSITORY=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)

echo "Creating Network Infrastructure..."

# create the VPC
echo "Creating VPC..."
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --profile production >> vpc.yml
VPC_ID=$(yq r vpc.yml Vpc.VpcId)
aws ec2 create-tags --resources $VPC_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created VPC with ID $VPC_ID"

# create public subnet (for EC2 instance)
echo "Creating public subnet..."
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/24 --availability-zone ca-central-1a --profile production >> public-subnet.yml
PUBLIC_SUBNET_ID=$(yq r public-subnet.yml Subnet.SubnetId)
aws ec2 create-tags --resources $PUBLIC_SUBNET_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created public subnet with ID $PUBLIC_SUBNET_ID"

# create private subnet #1 (for RDS instance)
echo "Creating private subnet #1..."
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ca-central-1a --profile production >> private-subnet-1.yml
PRIVATE_SUBNET_1_ID=$(yq r private-subnet-1.yml Subnet.SubnetId)
aws ec2 create-tags --resources $PRIVATE_SUBNET_1_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created private subnet #1 with ID $PRIVATE_SUBNET_1_ID"

# create private subnet #2 (for RDS instance)
echo "Creating private subnet #2..."
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ca-central-1b --profile production >> private-subnet-2.yml
PRIVATE_SUBNET_2_ID=$(yq r private-subnet-2.yml Subnet.SubnetId)
aws ec2 create-tags --resources $PRIVATE_SUBNET_2_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created private subnet #2 with ID $PRIVATE_SUBNET_2_ID"

# create subnet group out of private subnets for the RDS instance
echo "Creating private RB subnet group..."
aws rds create-db-subnet-group \
  --db-subnet-group-name $REPOSITORY \
  --db-subnet-group-description "Subnet group for RDS cluster" \
  --subnet-ids $PRIVATE_SUBNET_1_ID $PRIVATE_SUBNET_2_ID \
  --profile production \
  >> private-subnet-group.yml
echo "Created private RB subnet group"

# create internet gateway
echo "Creating internet gateway..."
aws ec2 create-internet-gateway --profile production >> gateway.yml
GATEWAY_ID=$(yq r gateway.yml InternetGateway.InternetGatewayId)
aws ec2 create-tags --resources $GATEWAY_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created internet gateway with ID $GATEWAY_ID"

# attach gateway to VPC
echo "Attaching gateway to VPC..."
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $GATEWAY_ID --profile production
echo "Attached gateway"

# create a custom public route table for vpc
echo "Creating custom public route table..."
aws ec2 create-route-table --vpc-id $VPC_ID --profile production >> public-route-table.yml
PUBLIC_ROUTE_TABLE_ID=$(yq r public-route-table.yml RouteTable.RouteTableId)
aws ec2 create-tags --resources $PUBLIC_ROUTE_TABLE_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Creating route to public internet..."
aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $GATEWAY_ID --profile production
echo "Associating route table with public subnet (making public)..."
aws ec2 associate-route-table  --subnet-id $PUBLIC_SUBNET_ID --route-table-id $ROUTE_TABLE_ID --profile production
echo "Created custom public route table"

# create a custom private route table for vpc
#echo "Creating custom private route table..."
#aws ec2 create-route-table --vpc-id $VPC_ID --profile production >> private-route-table.yml
#PRIVATE_ROUTE_TABLE_ID=$(yq r private-route-table.yml RouteTable.RouteTableId)
#aws ec2 create-tags --resources $PRIVATE_ROUTE_TABLE_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
#echo "Associating route table with private subnet #1..."
#aws ec2 associate-route-table  --subnet-id $PRIVATE_SUBNET_1_ID --route-table-id $ROUTE_TABLE_ID --profile production
#echo "Associating route table with private subnet #2..."
#aws ec2 associate-route-table  --subnet-id $PRIVATE_SUBNET_2_ID --route-table-id $ROUTE_TABLE_ID --profile production
#echo "Created custom private route table"

echo "Done."
