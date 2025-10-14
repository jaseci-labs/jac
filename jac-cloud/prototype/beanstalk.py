"""File covering beanstalk implementation."""

import os
from datetime import datetime

from aws import (
    create_application_version,
    ensure_environment_exists_docker,
    setup_iam_resources,
    upload_to_s3,
)

import boto3

from dotenv import load_dotenv

from utils import zip_project

load_dotenv()


def deploy_beanstalk() -> None:
    """Deploy example."""
    app_name = os.getenv("APP_NAME", "jaseci-app8")
    env_name = os.getenv("ENV_NAME", "development8")
    s3_bucket = os.getenv("S3_BUCKET", "jaseci-deploy")
    region = os.getenv("REGION", "us-east-1")
    zip_folder = os.getenv("FOLDER", "littleX")
    # Load credentials from environment (if any)
    aws_access_key_id = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_access_key = os.getenv("AWS_SECRET_ACCESS_KEY")

    # Ensure both or none are provided
    if bool(aws_access_key_id) ^ bool(aws_secret_access_key):
        raise ValueError(
            "Both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set, or neither."
        )

    # Create Elastic Beanstalk client
    if aws_access_key_id and aws_secret_access_key:
        print("Using provided AWS credentials...")
        eb_client = boto3.client(
            "elasticbeanstalk",
            region_name=region,
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            verify=True,
        )
    else:
        print(
            "Using pre-configured AWS credentials (from ~/.aws/credentials, IAM role, or environment)."
        )
        eb_client = boto3.client("elasticbeanstalk", region_name=region, verify=True)

    try:
        # Make a harmless call to verify credentials
        eb_client.describe_applications()
        print("✅ AWS credentials verified successfully.")
    except Exception:
        print("AWS credentials are wrong")
        return
    print("🚀 Starting Elastic Beanstalk deployment...")

    # Setup IAM resources first
    setup_iam_resources(app_name, region)

    version = datetime.now().strftime("%Y%m%d-%H%M%S")
    s3_key = f"{app_name}-{version}.zip"

    # 1️⃣ Zip the project
    print("\nPreparing application package...")
    zipped_file = zip_project(zip_folder)

    # 2️⃣ Upload to S3
    print("\n Uploading to S3...")
    upload_to_s3(region, zipped_file, s3_bucket, s3_key)

    # 3️⃣ Create application version (creates app if missing)
    print("\n Creating application version...")
    create_application_version(eb_client, app_name, s3_bucket, version, s3_key)

    # 4️⃣ Create or update environment with single instance
    print("\n Setting up environment...")
    ensure_environment_exists_docker(eb_client, version, region, app_name, env_name)

    print("\n Deployment complete!")
    print(
        " Tip: You can check the deployment status in the AWS Elastic Beanstalk console."
    )
    print(
        f" If deployment fails, check logs with: aws logs tail eb-engine.log --region {region}"
    )
    os.remove(zipped_file)


# ---- Main ----
if __name__ == "__main__":
    deploy_beanstalk()
