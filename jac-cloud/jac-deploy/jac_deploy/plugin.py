"""Plugin for jac deploy."""

import json
import os
from pathlib import Path

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

from utils import build_docker_image, create_dockerfile, run_docker_image


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def deploy(config_file: str) -> None:
            """Containerize the jac application."""
            with open(config_file, "r") as f:
                config = json.load(f)

            code_folder = config["build"].get("code_folder")
            requirements_file = config["build"].get("requirements_file")
            entrypoint_file = config["build"].get("entrypoint_file")

            if not Path(os.path.join(code_folder, requirements_file)).exists():
                raise FileNotFoundError(
                    f"Requirements file '{requirements_file}' not found."
                )

            if not Path(os.path.join(code_folder, entrypoint_file)).exists():
                raise FileNotFoundError(
                    f"entrypoint_file '{entrypoint_file}' not found."
                )
            if "dockerfile" not in os.listdir(code_folder):
                create_dockerfile(requirements_file, entrypoint_file, code_folder)

            image_name = config["build"].get("image_name")
            tag = config["build"].get("tag")
            container_name = config["deploy"].get("container_name")
            ports = config["deploy"].get("ports")
            build_docker_image(code_folder, image_name, tag)
            run_docker_image(image_name, tag, container_name, ports)
