"""DockerHub registry implementation."""
import docker;
import os;
import shutil;
import from typing { Any }
import from docker.errors { APIError, BuildError }
import from jac_scale.abstractions.image_registry { ImageRegistry }
import from jaclang.cli.console { console }

"""DockerHub image registry implementation."""
obj DockerHubRegistry(ImageRegistry) {
    has config: dict[str, Any] = {},
        docker_username: str by postinit,
        docker_password: str by postinit,
        build_platform: str by postinit;

    def postinit {
        self.docker_username = self.config.get('docker_username', '');
        self.docker_password = self.config.get('docker_password', '');
        self.build_platform = self.config.get('build_platform', 'linux/amd64');
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
        if not os.path.exists(dockerfile_path) {
            template_path = os.path.join(
                os.path.dirname(__file__),
                '../../targets/kubernetes/templates/base.Dockerfile'
            );
            shutil.copy(template_path, dockerfile_path);
            console.print(
                f"No Dockerfile found. Generated one from template at '{dockerfile_path}'."
            );
        }

        # Ensure .dockerignore excludes local override files
        dockerignore_path = os.path.join(code_folder, '.dockerignore');
        ignore_entries = ['jac.local.toml', 'jac.*.toml', '.env', '.jac/'];
        existing_entries: list[str] = [];
        if os.path.exists(dockerignore_path) {
            with open(dockerignore_path, 'r') as f {
                existing_entries = [line.strip() for line in f.readlines()];
            }
        }
        with open(dockerignore_path, 'a') as f {
            for entry in ignore_entries {
                if entry not in existing_entries {
                    f.write(f"{entry}\n");
                }
            }
        }

        # Build Docker image using Docker client
        docker_client = docker.from_env();
        console.print(f"Building Docker image '{repository_name}'...");
        try {
            build_kwargs: dict = {
                'path': code_folder,
                'tag': repository_name,
                'dockerfile': 'Dockerfile',
                'rm': True,
                'buildargs': {'TARGETPLATFORM': self.build_platform}
            };
            if self.build_platform {
                build_kwargs['platform'] = self.build_platform;
            }
            build_logs = docker_client.images.build(**build_kwargs);
            for chunk in build_logs[1] {
                line = chunk.get('stream', '').strip();
                if line {
                    console.print(f"  {line}");
                }
            }
        } except BuildError as e {
            raise RuntimeError(f"Failed to build Docker image: {e}") from e;
        }
        console.print(f"Docker image '{repository_name}' built successfully.");

        return repository_name;
    }

    def push_image(image_name: str) {
        # Push Docker image to DockerHub
        docker_client = docker.from_env();
        console.print(f"Pushing Docker image '{image_name}' to DockerHub...");
        try {
            docker_client.login(
                username=self.docker_username, password=self.docker_password
            );
            seen_statuses: set = set();
            for chunk in docker_client.images.push(
                image_name, stream=True, decode=True
            ) {
                if 'error' in chunk {
                    raise RuntimeError(f"Push failed: {chunk['error']}");
                }
                if 'status' in chunk and not chunk.get('progressDetail') {
                    layer_id = chunk.get('id', '');
                    status = chunk['status'];
                    key = f"{layer_id}:{status}";
                    if key not in seen_statuses {
                        seen_statuses.add(key);
                        msg = f"  [{layer_id}] {status}" if layer_id else f"  {status}";
                        console.print(msg);
                    }
                }
            }
        } except APIError as e {
            raise RuntimeError(f"Failed to push Docker image: {e}") from e;
        }
        console.print(f"Docker image '{image_name}' pushed successfully.");
    }

    def get_image_url(image_name: str) -> str {
        # If image_name doesn't include username, add it
        if '/' not in image_name {
            return f"{self.docker_username}/{image_name}";
        }
        return image_name;
    }
}
