"""File covering beanstalk implementation."""

# def get_latest_python_platform() -> str:
#     """Fetch the latest available Python platform for Amazon Linux 2023."""
#     stacks = eb_client.list_available_solution_stacks()["SolutionStacks"]
#     python_stacks = [s for s in stacks if "Amazon Linux 2023" in s and "Python" in s]
#     if not python_stacks:
#         raise RuntimeError("No Amazon Linux 2023 Python platform found in this region.")
#     python_stacks.sort(reverse=True)
#     latest = python_stacks[0]
#     print(f"ℹ Using latest platform: {latest}")
#     return latest

# def ensure_environment_exists_fastapi(eb_client,version_label: str,app_name: str, env_name: str) -> None:
#     """Temperary doc string."""
#     envs = eb_client.describe_environments(ApplicationName=app_name)["Environments"]
#     existing_env = next(
#         (env for env in envs if env["EnvironmentName"] == env_name), None
#     )
#     latest_platform = get_latest_python_platform()
#     account_id = get_account_id(REGION)
#     INSTANCE_PROFILE_NAME=f"{app_name}-ec2-instance-profile"
#     SERVICE_ROLE_NAME=f"{app_name}-service-role"
#     if not existing_env:
#         # Create environment with proper IAM roles
#         env_response = eb_client.create_environment(
#             ApplicationName=app_name,
#             EnvironmentName=env_name,
#             SolutionStackName=latest_platform,
#             VersionLabel=version_label,
#             Tier={"Name": "WebServer", "Type": "Standard"},
#             OptionSettings=[
#                 {
#                     "Namespace": "aws:elasticbeanstalk:environment",
#                     "OptionName": "EnvironmentType",
#                     "Value": "SingleInstance",
#                 },
#                 {
#                     "Namespace": "aws:autoscaling:launchconfiguration",
#                     "OptionName": "IamInstanceProfile",
#                     "Value": INSTANCE_PROFILE_NAME,
#                 },
#                 {
#                     "Namespace": "aws:elasticbeanstalk:environment",
#                     "OptionName": "ServiceRole",
#                     "Value": f"arn:aws:iam::{account_id}:role/{SERVICE_ROLE_NAME}",
#                 },
#             ],
#         )
#         print(
#             f"Created single-instance environment '{env_name}' with platform {latest_platform}"
#         )
#         print(f"Environment ID: {env_response.get('EnvironmentId')}")
#     else:
#         eb_client.update_environment(
#             ApplicationName=app_name,
#             EnvironmentName=env_name,
#             VersionLabel=version_label,
#         )
#         print(f"Updated environment '{env_name}' to version {version_label}")

#     # Wait for environment to be ready and fetch URL
#     print("Waiting for environment to be ready...")
#     waiter = eb_client.get_waiter("environment_updated")
#     try:
#         waiter.wait(
#             ApplicationName=app_name,
#             EnvironmentNames=[env_name],
#             WaiterConfig={"Delay": 30, "MaxAttempts": 20},
#         )

#         # Fetch environment URL and print it
#         env_info = eb_client.describe_environments(
#             ApplicationName=app_name, EnvironmentNames=[env_name]
#         )

#         if env_info["Environments"]:
#             env = env_info["Environments"][0]
#             if env.get("CNAME"):
#                 print(f"Your app is live at: http://{env['CNAME']}")
#             else:
#                 print(f"Environment created successfully. Status: {env.get('Status')}")

#     except Exception as e:
#         print(
#             "Environment creation may still be in progress. Check AWS console for status."
#         )
#         print(f"Error details: {str(e)}")
