"""Kubernetes-specific configuration."""
import from typing { Any }
import from jac_scale.abstractions.config.base_config { BaseConfig }

"""Configuration for Kubernetes deployments."""
class KubernetesConfig(BaseConfig) {
    has docker_image_name: str = '',
        docker_username: str = '',
        docker_password: str = '',
        container_port: int = 8000,
        node_port: int = 30001,
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
        prometheus_admin_password: str = 'Adminpassword123',
        prometheus_node_port: int = 30090,
        grafana_node_port: int = 30300;

    def init(
        self: KubernetesConfig,
        app_name: str = 'jaseci',
        namespace: str = 'default',
        docker_image_name: str = '',
        docker_username: str = '',
        docker_password: str = '',
        container_port: int = 8000,
        node_port: int = 30001,
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
        python_image: str = 'python:3.12-slim',
        busybox_image: str = 'busybox:1.36',
        wait_image: str = 'busybox',
        pvc_size: str = '5Gi',
        resource_deletion_wait: int = 5,
        aws_nlb_wait: int = 60,
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
        prometheus_admin_password: str = 'Adminpassword123',
        prometheus_node_port: int = 30090,
        grafana_node_port: int = 30300
    ) -> None {
        self.app_name = app_name;
        self.namespace = namespace;
        # Initialize derived class fields
        self.docker_image_name = docker_image_name;
        self.docker_username = docker_username;
        self.docker_password = docker_password;
        self.container_port = container_port;
        self.node_port = node_port;
        self.mongodb_enabled = mongodb_enabled;
        self.redis_enabled = redis_enabled;
        self.cpu_request = cpu_request;
        self.cpu_limit = cpu_limit;
        self.memory_request = memory_request;
        self.memory_limit = memory_limit;
        self.readiness_initial_delay = readiness_initial_delay;
        self.readiness_period = readiness_period;
        self.liveness_initial_delay = liveness_initial_delay;
        self.liveness_period = liveness_period;
        self.liveness_failure_threshold = liveness_failure_threshold;
        self.min_replicas = min_replicas;
        self.max_replicas = max_replicas;
        self.cpu_utilization_target = cpu_utilization_target;
        self.health_check_path = health_check_path;
        # Runtime configuration
        self.python_image = python_image;
        self.busybox_image = busybox_image;
        self.wait_image = wait_image;
        # Storage configuration
        self.pvc_size = pvc_size;
        # Timing configuration
        self.resource_deletion_wait = resource_deletion_wait;
        self.aws_nlb_wait = aws_nlb_wait;
        # Paths
        self.app_mount_path = app_mount_path;
        self.code_mount_path = code_mount_path;
        self.workspace_path = workspace_path;
        # Runtime environment
        self.jaseci_repo_url = jaseci_repo_url;
        self.jaseci_branch = jaseci_branch;
        self.jaseci_commit = jaseci_commit;
        self.install_jaseci = install_jaseci;
        self.additional_packages = additional_packages;
        self.plugin_versions = plugin_versions;
        # Monitoring configuration
        self.monitoring_enabled = monitoring_enabled;
        self.prometheus_admin_password = prometheus_admin_password;
        self.prometheus_node_port = prometheus_node_port;
        self.grafana_node_port = grafana_node_port;
    }

    override def to_dict(self: KubernetesConfig) -> dict[str, Any] {
        base = super.to_dict();
        base.update(
            {
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
                'prometheus_admin_password': self.prometheus_admin_password,
                'prometheus_node_port': self.prometheus_node_port,
                'grafana_node_port': self.grafana_node_port
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
            prometheus_admin_password=config.get(
                'prometheus_admin_password', 'Adminpassword123'
            ),
            prometheus_node_port=config.get('prometheus_node_port', 30090),
            grafana_node_port=config.get('grafana_node_port', 30300)
        );
    }
}
