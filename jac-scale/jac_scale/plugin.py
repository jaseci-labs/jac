"""File covering plugin implementation."""

import os
import pathlib

from dotenv import load_dotenv

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

from .kubernetes.docker_impl import build_and_push_docker
from .kubernetes.k8 import deploy_k8
from .kubernetes.utils import cleanup_k8_resources


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def scale(file_path: str, build: bool = False) -> None:
            """Jac Scale functionality."""
            load_dotenv()

            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: '{file_path}'")
            code_folder = os.path.dirname(file_path) or "."
            code_folder = os.path.relpath(code_folder)
            code_folder = pathlib.Path(code_folder).as_posix()
            base_file_path = os.path.basename(file_path)
            if build:
                build_and_push_docker(code_folder)
            deploy_k8(code_folder, base_file_path, build)

        @cmd_registry.register
        def destroy() -> None:
            """Jac Destroys functionality."""
            load_dotenv()
            cleanup_k8_resources()
