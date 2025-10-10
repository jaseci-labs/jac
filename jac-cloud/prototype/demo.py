"""Deploy example."""

import os

from beanstalk import deploy_beanstalk

from docker_impl import build_and_push_docker

from dotenv import load_dotenv

from k8 import deploy_k8


load_dotenv()
deployment_type = os.getenv("DEPLOYMENT_TYPE", "aws")

if deployment_type == "aws":
    deploy_beanstalk()
elif deployment_type == "k8":
    build_and_push_docker()
    deploy_k8()
