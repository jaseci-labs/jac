"""Base configuration for deployments."""
"""Base deployment configuration."""
class DeploymentConfig {
    has app_name: str;
    has namespace: str;
    has target_type: str = 'kubernetes';
    has build: bool = False;
    has code_folder: str;
    has file_name: str;
}

