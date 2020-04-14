#!/bin/bash

echo "Creating Network..."

# create the VPC
echo "Creating VPC..."
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --profile production >> vpc.yml
VPC_ID=$(yq r vpc.yml Vpc.VpcId)
aws ec2 create-tags --resources $VPC_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created VPC with ID $VPC_ID"

# create subnet
echo "Creating subnet..."
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/16 --profile production >> subnet.yml
SUBNET_ID=$(yq r subnet.yml Subnet.SubnetId)
aws ec2 create-tags --resources $SUBNET_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Created subnet with ID $SUBNET_ID"

# create internet gateway
echo "Creating internet gateway..."
aws ec2 create-internet-gateway --profile production >> gateway.yml
GATEWAY_ID=$(yq r gateway.yml InternetGateway.InternetGatewayId)
aws ec2 create-tags --resources $GATEWAY_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY--profile production
echo "Created internet gateway with ID $GATEWAY_ID"

# attach gateway to VPC
echo "Attaching gateway to VPC..."
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $GATEWAY_ID --profile production
echo "Attached gateway"

# create a custom route table for vpc
echo "Creating custom route table..."
aws ec2 create-route-table --vpc-id $VPC_ID --profile production >> route_table.yml
ROUTE_TABLE_ID=$(yq r route_table.yml RouteTable.RouteTableId)
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=commit,Value=$GITHUB_SHA Key=repository,Value=$GITHUB_REPOSITORY --profile production
echo "Creating route to public internet..."
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $GATEWAY_ID --profile production
echo "Associating route table with subnet (making public)..."
aws ec2 associate-route-table  --subnet-id $SUBNET_ID --route-table-id $ROUTE_TABLE_ID --profile production
echo "Created route table"

echo "Done."
