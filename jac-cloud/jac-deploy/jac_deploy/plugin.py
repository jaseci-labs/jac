"""Plugin for jac deploy."""

import subprocess
from datetime import datetime

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
