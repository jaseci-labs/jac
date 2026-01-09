"""Kubernetes-specific configuration."""
import from .base_config { DeploymentConfig }

"""Kubernetes deployment configuration."""
class KubernetesConfig(DeploymentConfig) {
    has node_port: int = 30001;
    has container_port: int = 8000;
    has storage_class: (str | None) = None;
    has cpu_request: (str | None) = None;
    has cpu_limit: (str | None) = None;
    has memory_request: (str | None) = None;
    has memory_limit: (str | None) = None;
}

