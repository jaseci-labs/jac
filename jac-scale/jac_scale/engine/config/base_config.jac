"""Base configuration for deployments."""
"""Base deployment configuration."""
class DeploymentConfig {
    has app_name: str,
        namespace: str,
        target_type: str = 'kubernetes',
        build: bool = False,
        code_folder: str,
        file_name: str;
}
