"""File covering Docker implementation."""
import os;
import docker;
import from docker.errors { APIError, BuildError }
import from jac_scale.config_loader { get_scale_config }

# Load kubernetes configuration from jac.toml with env var overrides
glob _k8s_config = get_scale_config().get_kubernetes_config();

def build_docker_image(
    image_name: str, code_folder: str, dockerfile: str = 'Dockerfile'
) -> None;

def push_docker_image(image_name: str, username: str, password: str) -> None;

def build_and_push_docker(code_folder: str) -> None;

with entry {
    if (__name__ == '__main__') {
        code_folder = os.getcwd();
        build_and_push_docker(code_folder);
    }
}
