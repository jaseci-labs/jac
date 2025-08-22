"""File covering beanstalk implementation."""

import json
import os
import time
import zipfile
from datetime import datetime

import boto3

from botocore.exceptions import ClientError

from dotenv import load_dotenv

load_dotenv()

APP_NAME = os.getenv("APP_NAME", "jaseci-app")
ENV_NAME = os.getenv("ENV_NAME", "dev")
S3_BUCKET = os.getenv("S3_BUCKET", "jaseci-s3")
REGION = os.getenv("REGION", "us-east-1")
ZIP_FILE = os.getenv("ZIP_FILE", "fastapi_app.zip")

# IAM Resources
INSTANCE_PROFILE_NAME = f"{APP_NAME}-ec2-instance-profile"
IAM_ROLE_NAME = f"{APP_NAME}-ec2-role"
SERVICE_ROLE_NAME = f"{APP_NAME}-service-role"

# AWS Clients
eb_client = boto3.client("elasticbeanstalk", region_name=REGION)
s3_client = boto3.client("s3", region_name=REGION)
iam_client = boto3.client("iam", region_name=REGION)


# ---- IAM Helper Functions ----
def create_ec2_instance_role() -> None:
    """Create IAM role for EC2 instances in Elastic Beanstalk."""
    # Trust policy for EC2 service
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
                "Action": "sts:AssumeRole",
            }
        ],
    }

    try:
        # Check if role already exists
        iam_client.get_role(RoleName=IAM_ROLE_NAME)
        print(f" IAM role '{IAM_ROLE_NAME}' already exists.")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchEntity":
            # Create the role
            iam_client.create_role(
                RoleName=IAM_ROLE_NAME,
                AssumeRolePolicyDocument=json.dumps(trust_policy),
                Description=f"IAM role for {APP_NAME} EC2 instances",
            )
            print(f" Created IAM role: {IAM_ROLE_NAME}")
        else:
            raise

    # Attach required policies
    required_policies = [
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker",
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
    ]

    for policy_arn in required_policies:
        try:
            iam_client.attach_role_policy(RoleName=IAM_ROLE_NAME, PolicyArn=policy_arn)
            print(f" Attached policy: {policy_arn}")
        except ClientError as e:
            if e.response["Error"]["Code"] == "EntityAlreadyExists":
                print(f" Policy already attached: {policy_arn}")
            else:
                raise


def create_instance_profile() -> None:
    """Create instance profile and associate it with the IAM role."""
    try:
        # Check if instance profile already exists
        iam_client.get_instance_profile(InstanceProfileName=INSTANCE_PROFILE_NAME)
        print(f" Instance profile '{INSTANCE_PROFILE_NAME}' already exists.")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchEntity":
            # Create instance profile
            iam_client.create_instance_profile(
                InstanceProfileName=INSTANCE_PROFILE_NAME
            )
            print(f" Created instance profile: {INSTANCE_PROFILE_NAME}")

            # Add role to instance profile
            iam_client.add_role_to_instance_profile(
                InstanceProfileName=INSTANCE_PROFILE_NAME, RoleName=IAM_ROLE_NAME
            )
            print(" Added role to instance profile")

            # Wait a bit for IAM propagation
            print(" Waiting for IAM resources to propagate...")
            time.sleep(10)
        else:
            raise


def create_service_role() -> None:
    """Create service role for Elastic Beanstalk."""
    # Trust policy for Elastic Beanstalk service
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Service": "elasticbeanstalk.amazonaws.com"},
                "Action": "sts:AssumeRole",
            }
        ],
    }

    try:
        # Check if service role already exists
        iam_client.get_role(RoleName=SERVICE_ROLE_NAME)
        print(f"ℹ Service role '{SERVICE_ROLE_NAME}' already exists.")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchEntity":
            # Create the service role
            iam_client.create_role(
                RoleName=SERVICE_ROLE_NAME,
                AssumeRolePolicyDocument=json.dumps(trust_policy),
                Description=f"Service role for {APP_NAME} Elastic Beanstalk",
            )
            print(f" Created service role: {SERVICE_ROLE_NAME}")
        else:
            raise

    # Attach required service policies
    service_policies = [
        "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth",
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy",
    ]

    for policy_arn in service_policies:
        try:
            iam_client.attach_role_policy(
                RoleName=SERVICE_ROLE_NAME, PolicyArn=policy_arn
            )
            print(f" Attached service policy: {policy_arn}")
        except ClientError as e:
            if e.response["Error"]["Code"] == "EntityAlreadyExists":
                print(f"ℹ Service policy already attached: {policy_arn}")
            else:
                raise


def setup_iam_resources() -> None:
    """Set up all required IAM resources."""
    print("🔐 Setting up IAM resources...")
    create_ec2_instance_role()
    create_instance_profile()
    create_service_role()
    print("✅ IAM resources setup complete!")


def get_account_id() -> str:
    """Get AWS account ID."""
    sts_client = boto3.client("sts", region_name=REGION)
    return sts_client.get_caller_identity()["Account"]


# ---- Original Helper Functions (Updated) ----
def get_latest_python_platform() -> str:
    """Fetch the latest available Python platform for Amazon Linux 2023."""
    stacks = eb_client.list_available_solution_stacks()["SolutionStacks"]
    python_stacks = [s for s in stacks if "Amazon Linux 2023" in s and "Python" in s]
    if not python_stacks:
        raise RuntimeError("No Amazon Linux 2023 Python platform found in this region.")
    python_stacks.sort(reverse=True)
    latest = python_stacks[0]
    print(f"ℹ Using latest platform: {latest}")
    return latest


def zip_project(source_dir: str, output_filename: str) -> None:
    """Temperary doc string."""
    with zipfile.ZipFile(output_filename, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(source_dir):
            for file in files:
                # Skip certain files
                if file in [
                    output_filename,
                    "__pycache__",
                    ".git",
                    ".env",
                    ".DS_Store",
                ]:
                    continue
                if file.endswith(".pyc") or file.startswith("."):
                    continue

                filepath = os.path.join(root, file)
                arcname = os.path.relpath(filepath, source_dir)
                zf.write(filepath, arcname)
                print(f" Added: {arcname}")
    print(f"Project zipped as {output_filename}")


def upload_to_s3(file_path: str, bucket: str, key: str) -> None:
    """Temperary doc string."""
    s3_client.upload_file(file_path, bucket, key)
    print(f"Uploaded {file_path} to s3://{bucket}/{key}")


def ensure_application_exists() -> None:
    """Temperary doc string."""
    apps = eb_client.describe_applications(ApplicationNames=[APP_NAME])["Applications"]
    if not apps:
        eb_client.create_application(
            ApplicationName=APP_NAME,
            Description="FastAPI app deployed via Python script",
        )
        print(f"Created application '{APP_NAME}'")
    else:
        print(f"ℹ Application '{APP_NAME}' already exists.")


def create_application_version(version_label: str, s3_key: str) -> None:
    """Temperary doc string."""
    ensure_application_exists()
    eb_client.create_application_version(
        ApplicationName=APP_NAME,
        VersionLabel=version_label,
        SourceBundle={"S3Bucket": S3_BUCKET, "S3Key": s3_key},
        Process=True,
    )
    print(f"Created application version: {version_label}")


def ensure_environment_exists(version_label: str) -> None:
    """Temperary doc string."""
    envs = eb_client.describe_environments(ApplicationName=APP_NAME)["Environments"]
    existing_env = next(
        (env for env in envs if env["EnvironmentName"] == ENV_NAME), None
    )
    latest_platform = get_latest_python_platform()
    account_id = get_account_id()

    if not existing_env:
        # Create environment with proper IAM roles
        env_response = eb_client.create_environment(
            ApplicationName=APP_NAME,
            EnvironmentName=ENV_NAME,
            SolutionStackName=latest_platform,
            VersionLabel=version_label,
            Tier={"Name": "WebServer", "Type": "Standard"},
            OptionSettings=[
                {
                    "Namespace": "aws:elasticbeanstalk:environment",
                    "OptionName": "EnvironmentType",
                    "Value": "SingleInstance",
                },
                {
                    "Namespace": "aws:autoscaling:launchconfiguration",
                    "OptionName": "IamInstanceProfile",
                    "Value": INSTANCE_PROFILE_NAME,
                },
                {
                    "Namespace": "aws:elasticbeanstalk:environment",
                    "OptionName": "ServiceRole",
                    "Value": f"arn:aws:iam::{account_id}:role/{SERVICE_ROLE_NAME}",
                },
            ],
        )
        print(
            f"Created single-instance environment '{ENV_NAME}' with platform {latest_platform}"
        )
        print(f"Environment ID: {env_response.get('EnvironmentId')}")
    else:
        eb_client.update_environment(
            ApplicationName=APP_NAME,
            EnvironmentName=ENV_NAME,
            VersionLabel=version_label,
        )
        print(f"Updated environment '{ENV_NAME}' to version {version_label}")

    # Wait for environment to be ready and fetch URL
    print("Waiting for environment to be ready...")
    waiter = eb_client.get_waiter("environment_updated")
    try:
        waiter.wait(
            ApplicationName=APP_NAME,
            EnvironmentNames=[ENV_NAME],
            WaiterConfig={"Delay": 30, "MaxAttempts": 20},
        )

        # Fetch environment URL and print it
        env_info = eb_client.describe_environments(
            ApplicationName=APP_NAME, EnvironmentNames=[ENV_NAME]
        )

        if env_info["Environments"]:
            env = env_info["Environments"][0]
            if env.get("CNAME"):
                print(f"Your app is live at: http://{env['CNAME']}")
            else:
                print(f"Environment created successfully. Status: {env.get('Status')}")

    except Exception as e:
        print(
            "Environment creation may still be in progress. Check AWS console for status."
        )
        print(f"Error details: {str(e)}")


# ---- Main ----
if __name__ == "__main__":
    print("🚀 Starting Elastic Beanstalk deployment...")

    # Setup IAM resources first
    setup_iam_resources()

    version = datetime.now().strftime("%Y%m%d-%H%M%S")
    s3_key = f"{APP_NAME}-{version}.zip"

    # 1️⃣ Zip the project
    print("\nPreparing application package...")
    zip_project("./fastapi-app", ZIP_FILE)

    # 2️⃣ Upload to S3
    print("\n Uploading to S3...")
    upload_to_s3(ZIP_FILE, S3_BUCKET, s3_key)

    # 3️⃣ Create application version (creates app if missing)
    print("\n Creating application version...")
    create_application_version(version, s3_key)

    # 4️⃣ Create or update environment with single instance
    print("\n Setting up environment...")
    ensure_environment_exists(version)

    print("\n Deployment complete!")
    print(
        " Tip: You can check the deployment status in the AWS Elastic Beanstalk console."
    )
    print(
        f" If deployment fails, check logs with: aws logs tail eb-engine.log --region {REGION}"
    )
