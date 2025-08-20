"""Plugin for jac deploy."""

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
            print("Hello, World!")
            create_dockerfile()
            print(folder_name)
