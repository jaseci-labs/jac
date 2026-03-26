"""Kubernetes-specific configuration."""
import from typing { Any }
import from jac_scale.abstractions.config.base_config { BaseConfig }

"""Configuration for Kubernetes deployments."""
obj KubernetesConfig(BaseConfig) {
    has docker_image_name: str = '',
        docker_username: str = '',
        docker_password: str = '',
        container_port: int = 8000,
        mongodb_enabled: bool = True,
        redis_enabled: bool = True,
        cpu_request: (str | None) = None,
        cpu_limit: (str | None) = None,
        memory_request: (str | None) = None,
        memory_limit: (str | None) = None,
        readiness_initial_delay: int = 10,
        readiness_period: int = 20,
        liveness_initial_delay: int = 10,
        liveness_period: int = 20,
        liveness_failure_threshold: int = 80,
        min_replicas: int = 1,
        max_replicas: int = 3,
        cpu_utilization_target: int = 50,
        health_check_path: str = '/docs',
        # Runtime configuration
        python_image: str = 'python:3.12-slim',
        busybox_image: str = 'busybox:1.36',
        wait_image: str = 'busybox',
        # Storage configuration
        pvc_size: str = '5Gi',
        # Timing configuration
        resource_deletion_wait: int = 5,
        aws_nlb_wait: int = 60,
        # Paths
        app_mount_path: str = '/app',
        code_mount_path: str = '/code',
        workspace_path: str = '/code/workspace',
        jaseci_repo_url: str = 'https://github.com/jaseci-labs/jaseci.git',
        jaseci_branch: str = 'main',
        jaseci_commit: (str | None) = None,
        install_jaseci: bool = True,
        additional_packages: list[str] = [],
        plugin_versions: dict[str, str] = {},
        monitoring_enabled: bool = False,
        k8s_metrics_enabled: bool = True,
        prometheus_admin_password: str = 'Adminpassword123',
        # Dashboard configuration
        redis_dashboard: bool = False,
        mongodb_dashboard: bool = False,
        mongo_express_username: str = 'admin',
        mongo_express_password: str = 'admin',
        redis_insight_username: str = 'admin',
        redis_insight_password: str = 'admin',
        mongodb_root_username: str = 'admin',
        mongodb_root_password: str = 'password',
        redis_username: str = 'admin',
        redis_password: str = 'password',
        # Ingress configuration
        ingress_node_port: int = 30080,
        # Rate limiting (DDoS protection) — applied as NGINX Ingress annotations.
        # limit_rps: sustained requests/sec per client IP.
        # limit_burst_multiplier: burst headroom (burst = limit_rps * multiplier).
        # limit_connections: max concurrent open connections per client IP.
        ingress_limit_rps: int = 20,
        ingress_limit_burst_multiplier: int = 5,
        ingress_limit_connections: int = 20,
        ingress_session_affinity: bool = True,
        # Domain / TLS configuration
        domain: str = "",
        cert_manager_email: str = "";

    override def to_dict -> dict[str, Any] {
        base = super.to_dict();
        base.update(
            {
                'docker_image_name': self.docker_image_name,
                'docker_username': self.docker_username,
                'docker_password': self.docker_password,
                'container_port': self.container_port,
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
                'min_replicas': self.min_replicas,
                'max_replicas': self.max_replicas,
                'cpu_utilization_target': self.cpu_utilization_target,
                'health_check_path': self.health_check_path,
                # Runtime configuration
                'python_image': self.python_image,
                'busybox_image': self.busybox_image,
                'wait_image': self.wait_image,
                # Storage configuration
                'pvc_size': self.pvc_size,
                # Timing configuration
                'resource_deletion_wait': self.resource_deletion_wait,
                'aws_nlb_wait': self.aws_nlb_wait,
                # Paths
                'app_mount_path': self.app_mount_path,
                'code_mount_path': self.code_mount_path,
                'workspace_path': self.workspace_path,
                # Runtime environment
                'jaseci_repo_url': self.jaseci_repo_url,
                'jaseci_branch': self.jaseci_branch,
                'jaseci_commit': self.jaseci_commit,
                'install_jaseci': self.install_jaseci,
                'additional_packages': self.additional_packages,
                'plugin_versions': self.plugin_versions,
                # Monitoring configuration
                'monitoring_enabled': self.monitoring_enabled,
                'k8s_metrics_enabled': self.k8s_metrics_enabled,
                'prometheus_admin_password': self.prometheus_admin_password,
                # Dashboard configuration
                'redis_dashboard': self.redis_dashboard,
                'mongodb_dashboard': self.mongodb_dashboard,
                'mongo_express_username': self.mongo_express_username,
                'mongo_express_password': self.mongo_express_password,
                'redis_insight_username': self.redis_insight_username,
                'redis_insight_password': self.redis_insight_password,
                'mongodb_root_username': self.mongodb_root_username,
                'mongodb_root_password': self.mongodb_root_password,
                'redis_username': self.redis_username,
                'redis_password': self.redis_password,
                # Ingress configuration
                'ingress_node_port': self.ingress_node_port,
                'ingress_limit_rps': self.ingress_limit_rps,
                'ingress_limit_burst_multiplier': self.ingress_limit_burst_multiplier,
                'ingress_limit_connections': self.ingress_limit_connections,
                'ingress_session_affinity': self.ingress_session_affinity,
                # Domain / TLS configuration
                'domain': self.domain,
                'cert_manager_email': self.cert_manager_email
            }
        );
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
            min_replicas=config.get('min_replicas', 1),
            max_replicas=config.get('max_replicas', 3),
            cpu_utilization_target=config.get('cpu_utilization_target', 50),
            health_check_path=config.get('health_check_path', '/docs'),
            python_image=config.get('python_image', 'python:3.12-slim'),
            busybox_image=config.get('busybox_image', 'busybox:1.36'),
            wait_image=config.get('wait_image', 'busybox'),
            pvc_size=config.get('pvc_size', '5Gi'),
            resource_deletion_wait=config.get('resource_deletion_wait', 5),
            aws_nlb_wait=config.get('aws_nlb_wait', 60),
            app_mount_path=config.get('app_mount_path', '/app'),
            code_mount_path=config.get('code_mount_path', '/code'),
            workspace_path=config.get('workspace_path', '/code/workspace'),
            jaseci_repo_url=config.get(
                'jaseci_repo_url', 'https://github.com/jaseci-labs/jaseci.git'
            ),
            jaseci_branch=config.get('jaseci_branch', 'main'),
            jaseci_commit=config.get('jaseci_commit'),
            install_jaseci=config.get('install_jaseci', True),
            additional_packages=config.get('additional_packages', []),
            plugin_versions=config.get('plugin_versions', {}),
            monitoring_enabled=config.get('monitoring_enabled', False),
            k8s_metrics_enabled=config.get('k8s_metrics_enabled', True),
            prometheus_admin_password=config.get(
                'prometheus_admin_password', 'Adminpassword123'
            ),
            redis_dashboard=config.get('redis_dashboard', False),
            mongodb_dashboard=config.get('mongodb_dashboard', False),
            mongo_express_username=config.get('mongo_express_username', 'admin'),
            mongo_express_password=config.get('mongo_express_password', 'admin'),
            redis_insight_username=config.get('redis_insight_username', 'admin'),
            redis_insight_password=config.get('redis_insight_password', 'admin'),
            mongodb_root_username=config.get('mongodb_root_username', 'admin'),
            mongodb_root_password=config.get('mongodb_root_password', 'password'),
            redis_username=config.get('redis_username', 'admin'),
            redis_password=config.get('redis_password', 'password'),
            ingress_node_port=config.get('ingress_node_port', 30080),
            ingress_limit_rps=config.get('ingress_limit_rps', 20),
            ingress_limit_burst_multiplier=config.get(
                'ingress_limit_burst_multiplier', 5
            ),
            ingress_limit_connections=config.get('ingress_limit_connections', 20),
            ingress_session_affinity=config.get('ingress_session_affinity', True),
            domain=config.get('domain', ''),
            cert_manager_email=config.get('cert_manager_email', '')
        );
    }
}
