"""DockerHub registry implementation."""
import os;
import from typing { Any }
import from jac_scale.abstractions.image_registry { ImageRegistry }
import from jac_scale.kubernetes.docker_impl { build_docker_image, push_docker_image }

"""DockerHub image registry implementation."""
class DockerHubRegistry(ImageRegistry) {
    has config: dict[str, Any] = {},
        docker_username: str = '',
        docker_password: str = '';

    def init(self: DockerHubRegistry, config: dict[str, Any] = {}) -> None {
        self.config = config;
        self.docker_username = config.get('docker_username', '')
        or os.getenv('DOCKER_USERNAME', 'juzailmlwork');
        self.docker_password = config.get('docker_password', '')
        or os.getenv('DOCKER_PASSWORD', '');
    }

    def build_image(
        self: DockerHubRegistry, code_folder: str, image_name: (str | None) = None
    ) -> str {
        if not image_name {
            app_name = self.config.get('app_name', 'jaseci');
            image_name = self.config.get('docker_image_name') or f"{app_name}:latest";
        }
        repository_name = f"{self.docker_username}/{image_name}";
        build_docker_image(image_name=repository_name, code_folder=code_folder);
        return repository_name;
    }

    def push_image(self: DockerHubRegistry, image_name: str) -> None {
        push_docker_image(
            image_name=image_name,
            username=self.docker_username,
            password=self.docker_password
        );
    }

    def get_image_url(self: DockerHubRegistry, image_name: str) -> str {
        # If image_name doesn't include username, add it
        if '/' not in image_name {
            return f"{self.docker_username}/{image_name}";
        }
        return image_name;
    }
}
