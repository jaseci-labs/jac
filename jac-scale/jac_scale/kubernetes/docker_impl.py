"""File covering Docker implementation."""

import os

import docker
from docker.errors import APIError, BuildError


def build_docker_image(
    image_name: str, code_folder: str, dockerfile: str = "Dockerfile"
) -> None:
    """
    Build a Docker image programmatically.

    Args:
        image_name (str): Name and tag for the image (e.g. 'jusail/fastapi-app:latest').
        code_folder (str): Path to the build context (where Dockerfile and app code reside).
        dockerfile (str): Dockerfile name (default: 'Dockerfile').

    Returns:
        Tuple[str, str]: The image name and its ID.
    """
    docker_file_path = os.path.join(code_folder, dockerfile)
    if not os.path.exists(docker_file_path):
        raise FileNotFoundError("Dockerfile is missing.")
    try:
        docker_client = docker.from_env()
        # Quick test to see if daemon is reachable
        docker_client.ping()
    except Exception as e:
        raise RuntimeError("Docker daemon is down or unreachable.") from e

    # print(f"Building Docker image '{image_name}' from {context_path}...")
    try:
        image, logs = docker_client.images.build(
            path=code_folder, dockerfile=dockerfile, tag=image_name, rm=True
        )
        print("image is built sucessfully with image id", image.id)
    except (BuildError, APIError) as e:
        print("Image build failed:", e)


def push_docker_image(
    image_name: str,
    username: str,
    password: str,
) -> None:
    """
    Push a Docker image to Docker Hub.

    Args:
        image_name (str): Full image name (e.g. 'jusail/fastapi-app:latest').
        username (str): Docker Hub username.
        password (str): Docker Hub password or access token.

    Returns:
        Tuple[bool, str]: (success_flag, log_file_path)
    """
    docker_client = docker.from_env()
    print("Logging in to Docker Hub...\n")
    docker_client.login(username=username, password=password)
    print("Login successful.\n")
    sucess = True
    print("pushing docker image to dockerhub")
    for line in docker_client.images.push(image_name, stream=True, decode=True):
        if "error" in line:
            sucess = False
            print("failed to push docker image")
            break
    if sucess:
        print("pushed image sucessfully to dockerhub")


def build_and_push_docker(code_folder: str) -> None:
    """Build and push docker image to dockerhub."""
    app_name = os.getenv("APP_NAME", "jaseci")
    image_name = os.getenv("DOCKER_IMAGE_NAME", f"{app_name}:latest")
    docker_username = os.getenv("DOCKER_USERNAME", "juzailmlwork")
    docker_password = os.getenv("DOCKER_PASSWORD", "12345")
    repository_name = f"{docker_username}/{image_name}"
    print("the repo name is", repository_name)
    build_docker_image(image_name=repository_name, code_folder=code_folder)
    push_docker_image(
        image_name=repository_name, username=docker_username, password=docker_password
    )


if __name__ == "__main__":
    code_folder = os.getcwd()
    build_and_push_docker(code_folder)
