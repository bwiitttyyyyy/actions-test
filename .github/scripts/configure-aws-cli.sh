echo "Configuring AWS CLI..."

# verify that all of the necessary environment variables are set
[ -z "$AWS_ACCESS_KEY_ID_PRODUCTION" ] && echo "AWS_ACCESS_KEY_ID_PRODUCTION not set" && exit 1
[ -z "$AWS_SECRET_ACCESS_KEY_PRODUCTION" ] && echo "AWS_SECRET_ACCESS_KEY_PRODUCTION not set" && exit 1
[ -z "$AWS_ACCESS_KEY_ID_STAGING" ] && echo "AWS_ACCESS_KEY_ID_STAGING not set" && exit 1
[ -z "$AWS_ACCESS_KEY_ID_STAGING" ] && echo "AWS_SECRET_ACCESS_KEY_STAGING  not set" && exit 1

mkdir ~/.aws
cp ./.github/resources/aws/* ~/.aws/

echo "Creating production profile..."
echo "[production]" >> ~/.aws/credentials
echo "aws_access_key_id=$AWS_ACCESS_KEY_ID_PRODUCTION" >> ~/.aws/credentials
echo "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY_PRODUCTION" >> ~/.aws/credentials

echo "Creating staging profile..."
echo "[staging]" >> ~/.aws/credentials
echo "aws_access_key_id=$AWS_ACCESS_KEY_ID_STAGING" >> ~/.aws/credentials
echo "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY_STAGING" >> ~/.aws/credentials

echo "Done."
