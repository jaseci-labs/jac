"""Plugin for jac deploy."""

import json
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional


from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl


DOCKER_TEMPLATE = """\
FROM python:3.12.3-slim

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
ADD requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
ADD . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["jac", "serve", "{main_file}"]
"""


def create_dockerfile(requirements_file: str, main_file: str, folder: str) -> None:
    """Create dockerfile."""
    path = os.path.join(folder, "dockerfile")
    dockerfile_content = DOCKER_TEMPLATE.format(main_file=main_file)
    with open(path, "w") as f:
        f.write(dockerfile_content)
    print(f"{path} has been created successfully!")


def build_docker_image(
    code_folder: str,
    image_name: str,
    tag: str = "latest",
    log_file: str = "docker_build.log",
) -> None:
    """Build Docker image from specified folder and save logs."""
    code_folder_path = Path(code_folder)
    if not code_folder_path.exists():
        raise FileNotFoundError(f"Code folder '{code_folder}' not found.")

    cmd = ["docker", "build", "-t", f"{image_name}:{tag}", "."]

    print(f"Running: {' '.join(cmd)} in {code_folder}")

    # Open log file in append mode
    with open(log_file, "w") as log:
        log.write(f"\n\n---- Build started at {datetime.now()} ----\n")
        try:
            # Run Docker build in the specified folder
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(code_folder_path),  # Change working directory
            )

            if process.stdout is not None:
                for line in process.stdout:
                    # print(line, end="")
                    log.write(line)

            process.wait()

            if process.returncode == 0:
                print(f"Docker image '{image_name}:{tag}' built successfully!")
                log.write(f"\nBuild completed successfully at {datetime.now()}\n")
            else:
                print("Docker build failed. Check logs for details.")
                log.write(f"\nBuild failed at {datetime.now()}\n")

        except Exception as e:
            print(f"Error running Docker build: {e}")
            log.write(f"\nException during build: {e}\n")


def run_docker_image(
    image_name: str,
    tag: str = "latest",
    container_name: Optional[str] = None,
    ports: Optional[Dict[int, int]] = None,
    env_vars: Optional[Dict[str, str]] = None,
    log_file: str = "docker_run.log",
) -> None:
    """
    Run a Docker image locally with optional ports, environment variables, and log capture.

    Args:
        image_name (str): Name of the Docker image.
        tag (str): Image tag (default: "latest").
        container_name (Optional[str]): Name of the container (default: None).
        ports (Optional[Dict[int, int]]): Port mappings {host_port: container_port}.
        env_vars (Optional[Dict[str, str]]): Environment variables {KEY: VALUE}.
        log_file (str): File to save logs (default: "docker_run.log").
    """
    cmd = ["docker", "run", "--rm", "-d"]

    if container_name:
        cmd += ["--name", container_name]

    if ports:
        for host_port, container_port in ports.items():
            cmd += ["-p", f"{host_port}:{container_port}"]

    if env_vars:
        for key, value in env_vars.items():
            cmd += ["-e", f"{key}={value}"]

    cmd.append(f"{image_name}:{tag}")

    print(f"Running: {' '.join(cmd)}")

    with open(log_file, "w") as log, subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    ) as process:
        log.write(f"\n\n---- Run started at {datetime.now()} ----\n")
        if process.stdout:
            for line in process.stdout:
                # print(line, end="")
                log.write(line)

        process.wait()

        if process.returncode == 0:
            log.write(f"\nRun completed successfully at {datetime.now()}\n")
            print(f"Docker container '{container_name}' started successfully.")
        else:
            log.write(f"\nRun failed at {datetime.now()}\n")
            print("Docker run failed. Check logs for details.")


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
