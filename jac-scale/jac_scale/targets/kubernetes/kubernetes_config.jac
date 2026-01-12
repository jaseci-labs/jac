"""Kubernetes-specific configuration."""
import from typing { Any }
import from jac_scale.abstractions.config.base_config { BaseConfig }

"""Configuration for Kubernetes deployments."""
class KubernetesConfig(BaseConfig) {
    has docker_image_name: str = '';
    has docker_username: str = '';
    has docker_password: str = '';
    has container_port: int = 8000;
    has node_port: int = 30001;
    has mongodb_enabled: bool = True;
    has redis_enabled: bool = True;
    has cpu_request: (str | None) = None;
    has cpu_limit: (str | None) = None;
    has memory_request: (str | None) = None;
    has memory_limit: (str | None) = None;
    has readiness_initial_delay: int = 10;
    has readiness_period: int = 20;
    has liveness_initial_delay: int = 10;
    has liveness_period: int = 20;
    has liveness_failure_threshold: int = 80;
    has health_check_path: str = '/docs';

    override def to_dict(self: KubernetesConfig) -> dict[str, Any] {
        base = super().to_dict();
        base.update({
            'docker_image_name': self.docker_image_name,
            'docker_username': self.docker_username,
            'docker_password': self.docker_password,
            'container_port': self.container_port,
            'node_port': self.node_port,
            'mongodb_enabled': self.mongodb_enabled,
            'redis_enabled': self.redis_enabled,
            'cpu_request': self.cpu_request,
            'cpu_limit': self.cpu_limit,
            'memory_request': self.memory_request,
            'memory_limit': self.memory_limit,
            'readiness_initial_delay': self.readiness_initial_delay,
            'readiness_period': self.readiness_period,
            'liveness_initial_delay': self.liveness_initial_delay,
            'liveness_period': self.liveness_period,
            'liveness_failure_threshold': self.liveness_failure_threshold,
            'health_check_path': self.health_check_path
        });
        return base;
    }

    static def from_dict(cls: type, config: dict[str, Any]) -> KubernetesConfig {
        return cls(
            app_name=config.get('app_name', 'jaseci'),
            namespace=config.get('namespace', 'default'),
            docker_image_name=config.get('docker_image_name', ''),
            docker_username=config.get('docker_username', ''),
            docker_password=config.get('docker_password', ''),
            container_port=config.get('container_port', 8000),
            node_port=config.get('node_port', 30001),
            mongodb_enabled=config.get('mongodb_enabled', True),
            redis_enabled=config.get('redis_enabled', True),
            cpu_request=config.get('cpu_request'),
            cpu_limit=config.get('cpu_limit'),
            memory_request=config.get('memory_request'),
            memory_limit=config.get('memory_limit'),
            readiness_initial_delay=config.get('readiness_initial_delay', 10),
            readiness_period=config.get('readiness_period', 20),
            liveness_initial_delay=config.get('liveness_initial_delay', 10),
            liveness_period=config.get('liveness_period', 20),
            liveness_failure_threshold=config.get('liveness_failure_threshold', 80),
            health_check_path=config.get('health_check_path', '/docs')
        );
    }
}

