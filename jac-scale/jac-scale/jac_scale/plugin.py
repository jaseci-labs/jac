"""File covering plugin implementation."""

import os

from dotenv import load_dotenv

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

from .beanstalk import deploy_beanstalk
from .docker_impl import build_and_push_docker
from .k8 import deploy_k8


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def scale(code_folder: str, implementation_type: str) -> None:
            """Jac Scale functionality."""
            load_dotenv()
            deployment_type = os.getenv("DEPLOYMENT_TYPE", "aws")

            if deployment_type == "aws":
                deploy_beanstalk()
            elif deployment_type == "k8":
                build_and_push_docker()
                deploy_k8()

        @cmd_registry.register
        def destroy() -> None:
            """Jac Destroys functionality."""
            print("Hello, Jac learner lets stop your application!")
