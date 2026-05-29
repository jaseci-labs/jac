"""DockerHub registry implementation."""
import from pathlib { Path }
import from typing { Any }
import from jac_scale._optdeps.docker { docker_module as docker, APIError, BuildError }
import from jac_scale.abstractions.image_registry { ImageRegistry }
import from jac_scale.microservices.images.build_helpers {
    resolve_dockerfile,
    ensure_dockerignore
}
import from jaclang.cli.console { console }

"""DockerHub image registry implementation."""
obj DockerHubRegistry(ImageRegistry) {
    has config: dict[str, any] = {},
        docker_username: str by postinit,
        docker_password: str by postinit,
        build_platform: str by postinit,
        _client: Any = None;

    def postinit {
        self.docker_username = self.config.get('docker_username', '');
        self.docker_password = self.config.get('docker_password', '');
        self.build_platform = self.config.get('build_platform', 'linux/amd64');
        if not self.docker_username {
            raise ValueError(
                "docker_username is not set. Add 'docker_username' under [plugins.scale.kubernetes] in jac.local.toml."
            );
        }
        if not self.docker_password {
            raise ValueError(
                "docker_password is not set. Add 'docker_password' under [plugins.scale.kubernetes] in jac.local.toml."
            );
        }
    }

    def _get_client -> Any {
        if self._client is None {
            self._client = docker.from_env();
        }
        return self._client;
    }

    def build_image(code_folder: str, image_name: (str | None) = None) -> str {
        if not image_name {
            app_name = self.config.get('app_name', 'jaseci');
            image_name = self.config.get('docker_image_name') or f"{app_name}:latest";
        }
        repository_name = f"{self.docker_username}/{image_name}";

        project_path = Path(code_folder);
        (dockerfile_path, context_dir, build_args) = resolve_dockerfile(project_path);
        ensure_dockerignore(context_dir);

        # Build Docker image using Docker client
        console.print(f"Building Docker image '{repository_name}'...");
        try {
            build_logs = self._get_client().images.build(
                path=str(context_dir),
                tag=repository_name,
                dockerfile=str(dockerfile_path),
                buildargs=build_args or None,
                rm=True,
                platform=self.build_platform
            );
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
        console.print(f"Pushing Docker image '{image_name}' to DockerHub...");
        try {
            client = self._get_client();
            client.login(username=self.docker_username, password=self.docker_password);
            seen_statuses: set = set();
            for chunk in client.images.push(image_name, stream=True, decode=True) {
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
