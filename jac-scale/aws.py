"""File covering beanstalk implementation."""

import json
import os
import time

import boto3


from botocore.exceptions import ClientError

from dotenv import dotenv_values

from mypy_boto3_elasticbeanstalk import ElasticBeanstalkClient

from mypy_boto3_iam import IAMClient


def create_ec2_instance_role(iam_client: IAMClient, app_name: str) -> None:
    """Create IAM role for EC2 instances in Elastic Beanstalk."""
    iam_role_name = f"{app_name}-ec2-role"
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
        iam_client.get_role(RoleName=iam_role_name)
        print(f" IAM role '{iam_role_name}' already exists.")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchEntity":
            iam_client.create_role(
                RoleName=iam_role_name,
                AssumeRolePolicyDocument=json.dumps(trust_policy),
                Description=f"IAM role for {app_name} EC2 instances",
            )
            print(f" Created IAM role: {iam_role_name}")
        else:
            raise

    required_policies = [
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker",
        "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
    ]

    for policy_arn in required_policies:
        try:
            iam_client.attach_role_policy(RoleName=iam_role_name, PolicyArn=policy_arn)
            # print(f" Attached policy: {policy_arn}")
        except ClientError as e:
            if e.response["Error"]["Code"] == "EntityAlreadyExists":
                print(f" Policy already attached: {policy_arn}")
            else:
                raise


def create_instance_profile(iam_client: IAMClient, app_name: str) -> None:
    """Create instance profile and associate it with the IAM role."""
    instance_profile_name = f"{app_name}-ec2-instance-profile"
    iam_role_name = f"{app_name}-ec2-role"
    try:
        iam_client.get_instance_profile(InstanceProfileName=instance_profile_name)
        print(f" Instance profile '{instance_profile_name}' already exists.")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchEntity":
            iam_client.create_instance_profile(
                InstanceProfileName=instance_profile_name
            )
            print(f" Created instance profile: {instance_profile_name}")

            iam_client.add_role_to_instance_profile(
                InstanceProfileName=instance_profile_name, RoleName=iam_role_name
            )
            print(" Added role to instance profile")
            print(" Waiting for IAM resources to propagate...")
            time.sleep(10)
        else:
            raise


def create_service_role(iam_client: IAMClient, app_name: str) -> None:
    """Create service role for Elastic Beanstalk."""
    # Trust policy for Elastic Beanstalk service
    service_role_name = f"{app_name}-service-role"
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
        iam_client.get_role(RoleName=service_role_name)
        print(f"Service role '{service_role_name}' already exists.")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchEntity":
            # Create the service role
            iam_client.create_role(
                RoleName=service_role_name,
                AssumeRolePolicyDocument=json.dumps(trust_policy),
                Description=f"Service role for {app_name} Elastic Beanstalk",
            )
            print(f" Created service role: {service_role_name}")
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
                RoleName=service_role_name, PolicyArn=policy_arn
            )
            # print(f" Attached service policy: {policy_arn}")
        except ClientError as e:
            if e.response["Error"]["Code"] == "EntityAlreadyExists":
                print(f"Service policy already attached: {policy_arn}")
            else:
                raise


def setup_iam_resources(app_name: str, region: str) -> None:
    """Set up all required IAM resources."""
    iam_client = boto3.client("iam", region_name=region)
    print("Setting up IAM resources...")
    create_ec2_instance_role(iam_client, app_name)
    create_instance_profile(iam_client, app_name)
    create_service_role(iam_client, app_name)
    print("IAM resources setup complete!")


def get_account_id(region: str) -> str:
    """Get AWS account ID."""
    sts_client = boto3.client("sts", region_name=region)
    return sts_client.get_caller_identity()["Account"]


def ensure_application_exists(eb_client: ElasticBeanstalkClient, app_name: str) -> None:
    """Temperary doc string."""
    apps = eb_client.describe_applications(ApplicationNames=[app_name])["Applications"]
    if not apps:
        eb_client.create_application(
            ApplicationName=app_name,
            Description="FastAPI app deployed via Python script",
        )
        print(f"Created application '{app_name}'")
    else:
        print(f"Application '{app_name}' already exists.")


def create_application_version(
    eb_client: ElasticBeanstalkClient,
    app_name: str,
    s3_bucket: str,
    version_label: str,
    s3_key: str,
) -> None:
    """Temperary doc string."""
    ensure_application_exists(eb_client, app_name)
    eb_client.create_application_version(
        ApplicationName=app_name,
        VersionLabel=version_label,
        SourceBundle={"S3Bucket": s3_bucket, "S3Key": s3_key},
        Process=True,
    )
    print(f"Created application version: {version_label}")


def upload_to_s3(region: str, file_path: str, bucket: str, key: str) -> None:
    """Upload file to S3, create bucket if missing."""
    print("File path is:", file_path)

    s3_client = boto3.client("s3", region_name=region)

    try:
        s3_client.head_bucket(Bucket=bucket)
        print(f"Bucket '{bucket}' already exists.")
    except ClientError as e:
        error_code = int(e.response["Error"]["Code"])
        if error_code == 404:
            print(f"Bucket '{bucket}' not found. Creating new bucket...")
            if region == "us-east-1":
                s3_client.create_bucket(Bucket=bucket)
            else:
                s3_client.create_bucket(
                    Bucket=bucket,
                    CreateBucketConfiguration={"LocationConstraint": region},
                )
            print(f"Bucket '{bucket}' created successfully.")
        else:
            raise e

    # Upload file
    s3_client.upload_file(file_path, bucket, key)
    print(f"Uploaded {file_path} to s3://{bucket}/{key}")


def ensure_environment_exists_docker(
    eb_client: ElasticBeanstalkClient,
    version_label: str,
    region: str,
    app_name: str,
    env_name: str,
    options_settings: list,
) -> None:
    """Temperary doc string."""
    envs = eb_client.describe_environments(ApplicationName=app_name)["Environments"]
    existing_env = next(
        (env for env in envs if env["EnvironmentName"] == env_name), None
    )
    account_id = get_account_id(region)
    instance_profile_name = f"{app_name}-ec2-instance-profile"
    service_role_name = f"{app_name}-service-role"
    platforms = eb_client.list_platform_versions(
        Filters=[
            {
                "Type": "PlatformName",
                "Operator": "=",
                "Values": ["Docker running on 64bit Amazon Linux 2"],
            }
        ]
    )

    platform_list = sorted(
        platforms["PlatformSummaryList"],
        key=lambda x: x["PlatformVersion"],
        reverse=True,
    )

    if not platform_list:
        raise RuntimeError("No Docker platform found in this region!")

    platform_arn = platform_list[0]["PlatformArn"]
    if not existing_env:
        first_time_options_settings = [
            {
                "Namespace": "aws:elasticbeanstalk:environment",
                "OptionName": "EnvironmentType",
                "Value": "SingleInstance",
            },
            {
                "Namespace": "aws:autoscaling:launchconfiguration",
                "OptionName": "IamInstanceProfile",
                "Value": instance_profile_name,
            },
            {
                "Namespace": "aws:elasticbeanstalk:environment",
                "OptionName": "ServiceRole",
                "Value": f"arn:aws:iam::{account_id}:role/{service_role_name}",
            },
        ]
        options_settings.extend(first_time_options_settings)

        # env_response = eb_client.create_environment(
        eb_client.create_environment(
            ApplicationName=app_name,
            EnvironmentName=env_name,
            VersionLabel=version_label,
            PlatformArn=platform_arn,
            OptionSettings=options_settings,
        )
        print(f"Created single-instance environment '{env_name}'")
        # print(f"Environment ID: {env_response.get('EnvironmentId')}")
    else:
        eb_client.update_environment(
            ApplicationName=app_name,
            EnvironmentName=env_name,
            VersionLabel=version_label,
            OptionSettings=options_settings,
        )
        print(f"Updated environment '{env_name}' to version {version_label}")

    # Wait for environment to be ready and fetch URL
    print("Waiting for environment to be ready...")
    waiter = eb_client.get_waiter("environment_updated")
    try:
        waiter.wait(
            ApplicationName=app_name,
            EnvironmentNames=[env_name],
            WaiterConfig={"Delay": 30, "MaxAttempts": 20},
        )

        # Fetch environment URL and print it
        env_info = eb_client.describe_environments(
            ApplicationName=app_name, EnvironmentNames=[env_name]
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


def load_env_variables(code_folder: str = ".env") -> list:
    """Temperary doc string."""
    env_file = os.path.join(code_folder, ".env")
    env_vars = dotenv_values(env_file)
    option_settings = []
    if os.path.exists(env_file):
        for key, value in env_vars.items():
            option_settings.append(
                {
                    "Namespace": "aws:elasticbeanstalk:application:environment",
                    "OptionName": key,
                    "Value": value,
                }
            )
    return option_settings


def availability_precheck(code_folder: str) -> None:
    """Temperary doc string."""
    all_files = os.listdir(code_folder)
    needed_files = ["Dockerfile", "requirements.txt"]

    missing_files = [f for f in needed_files if f not in all_files]

    if missing_files:
        raise FileNotFoundError(f"Missing required files: {', '.join(missing_files)}")
    else:
        print("All required files are available.")
