echo "Creating EC2 instance..."

# aws ec2 run-instances --image-id ami-173d747e --count 1 --instance-type t1.micro --key-name MyKeyPair --security-groups my-sg
#aws ec2 run-instances --count 1 --instance-type t1.micro --key-name MyKeyPair --security-groups my-sg


echo "Done."
