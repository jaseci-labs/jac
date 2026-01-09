"""Kubernetes-specific configuration."""
import from .base_config { DeploymentConfig }

"""Kubernetes deployment configuration."""
class KubernetesConfig(DeploymentConfig) {
    has node_port: int = 30001,
        container_port: int = 8000,
        storage_class: (str | None) = None,
        cpu_request: (str | None) = None,
        cpu_limit: (str | None) = None,
        memory_request: (str | None) = None,
        memory_limit: (str | None) = None;
}
