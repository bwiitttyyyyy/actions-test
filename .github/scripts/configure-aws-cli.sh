echo "Configuring AWS CLI..."

echo "cwd: $CWD"

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
