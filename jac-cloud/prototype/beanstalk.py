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

APP_NAME = os.getenv("APP_NAME", "jaseci-app8")
ENV_NAME = os.getenv("ENV_NAME", "development8")
S3_BUCKET = os.getenv("S3_BUCKET", "jaseci-deploy")
REGION = os.getenv("REGION", "us-east-1")
ZIP_FOLDER = os.getenv("ZIP_FOLDER", "littleX")

eb_client = boto3.client("elasticbeanstalk", region_name=REGION)

# ---- Main ----
if __name__ == "__main__":
    print("🚀 Starting Elastic Beanstalk deployment...")

    # Setup IAM resources first
    setup_iam_resources(APP_NAME, REGION)

    version = datetime.now().strftime("%Y%m%d-%H%M%S")
    s3_key = f"{APP_NAME}-{version}.zip"

    # 1️⃣ Zip the project
    print("\nPreparing application package...")
    zipped_file = zip_project(ZIP_FOLDER)

    # 2️⃣ Upload to S3
    print("\n Uploading to S3...")
    upload_to_s3(REGION, zipped_file, S3_BUCKET, s3_key)

    # 3️⃣ Create application version (creates app if missing)
    print("\n Creating application version...")
    create_application_version(eb_client, APP_NAME, S3_BUCKET, version, s3_key)

    # 4️⃣ Create or update environment with single instance
    print("\n Setting up environment...")
    ensure_environment_exists_docker(eb_client, version, REGION, APP_NAME, ENV_NAME)

    print("\n Deployment complete!")
    print(
        " Tip: You can check the deployment status in the AWS Elastic Beanstalk console."
    )
    print(
        f" If deployment fails, check logs with: aws logs tail eb-engine.log --region {REGION}"
    )
    os.remove(zipped_file)
