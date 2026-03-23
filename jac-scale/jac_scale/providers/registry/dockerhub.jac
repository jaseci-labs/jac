"""DockerHub registry implementation."""
import docker;
import os;
import shutil;
import from typing { Any }
import from docker.errors { APIError, BuildError }
import from jac_scale.abstractions.image_registry { ImageRegistry }

"""DockerHub image registry implementation."""
obj DockerHubRegistry(ImageRegistry) {
    has config: dict[str, Any] = {},
        docker_username: str by postinit,
        docker_password: str by postinit;

    def postinit {
        self.docker_username = self.config.get('docker_username', '');
        self.docker_password = self.config.get('docker_password', '');
    }

    def build_image(code_folder: str, image_name: (str | None) = None) -> str {
        if not self.docker_username {
            raise ValueError(
                "docker_username is not set. Add 'docker_username' under [plugins.scale.kubernetes] in jac.toml."
            );
        }
        if not self.docker_password {
            raise ValueError(
                "docker_password is not set. Add 'docker_password' under [plugins.scale.kubernetes] in jac.toml."
            );
        }
        if not image_name {
            app_name = self.config.get('app_name', 'jaseci');
            image_name = self.config.get('docker_image_name') or f"{app_name}:latest";
        }
        repository_name = f"{self.docker_username}/{image_name}";

        # Generate a Dockerfile from template if one doesn't exist in the code folder
        dockerfile_path = os.path.join(code_folder, 'Dockerfile');
        generated_dockerfile: (str | None) = None;
        if not os.path.exists(dockerfile_path) {
            template_path = os.path.join(
                os.path.dirname(__file__),
                '../../targets/kubernetes/templates/base.Dockerfile'
            );
            shutil.copy(template_path, dockerfile_path);
            generated_dockerfile = dockerfile_path;
        }

        # Build Docker image using Docker client
        docker_client = docker.from_env();
        try {
            docker_client.images.build(
                path=code_folder, tag=repository_name, dockerfile='Dockerfile', rm=True
            );
        } except BuildError as e {
            raise RuntimeError(f"Failed to build Docker image: {e}") from e;
        } finally {
            if generated_dockerfile {
                os.remove(generated_dockerfile);
            }
        }

        return repository_name;
    }

    def push_image(image_name: str) -> None {
        # Push Docker image to DockerHub
        docker_client = docker.from_env();
        try {
            docker_client.login(
                username=self.docker_username, password=self.docker_password
            );
            docker_client.images.push(image_name);
        } except APIError as e {
            raise RuntimeError(f"Failed to push Docker image: {e}") from e;
        }
    }

    def get_image_url(image_name: str) -> str {
        # If image_name doesn't include username, add it
        if '/' not in image_name {
            return f"{self.docker_username}/{image_name}";
        }
        return image_name;
    }
}
