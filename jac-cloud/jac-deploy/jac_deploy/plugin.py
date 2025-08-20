"""Plugin for jac deploy."""

import subprocess
from datetime import datetime
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
CMD ["jac", "serve", "tobu_main.jac"]
"""


def create_dockerfile(filename: str = "Dockerfile") -> None:
    """Create dockerfile."""
    with open(filename, "w") as f:
        f.write(DOCKER_TEMPLATE)
    print(f"{filename} has been created successfully!")


def build_docker_image(
    image_name: str, tag: str = "latest", log_file: str = "docker_build.log"
) -> None:
    """Build Docker image and save logs."""
    cmd = ["docker", "build", "-t", f"{image_name}:{tag}", "."]
    print(f"Running: {' '.join(cmd)}")

    # Open log file with timestamped logging
    with open(log_file, "a") as log:
        log.write(f"\n\n---- Build started at {datetime.now()} ----\n")
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )

        with subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        ) as process:
            if process.stdout:
                for line in process.stdout:
                    print(line, end="")
                    log.write(line)
            process.wait()

        process.wait()
        if process.returncode == 0:
            print(f"Docker image '{image_name}:{tag}' built successfully!")
            log.write(f"\nBuild completed successfully at {datetime.now()}\n")
        else:
            print("Docker build failed. Check logs for details.")
            log.write(f"\nBuild failed at {datetime.now()}\n")


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
    cmd = ["docker", "run", "--rm"]

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

    with open(log_file, "a") as log, subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    ) as process:
        log.write(f"\n\n---- Run started at {datetime.now()} ----\n")
        if process.stdout:
            for line in process.stdout:
                print(line, end="")
                log.write(line)
        process.wait()
        if process.returncode == 0:
            log.write(f"\nRun completed successfully at {datetime.now()}\n")
            print(f"Docker container '{image_name}:{tag}' finished successfully.")
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
        def deploy(
            folder_name: str, requirements_file: str = "test1", main_file: str = "test2"
        ) -> None:
            """Containarize the jac application."""
            create_dockerfile()
            # build_docker_image("jac-deploy", tag="v1")
