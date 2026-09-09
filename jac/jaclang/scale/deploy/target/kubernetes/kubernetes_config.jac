import from jaclang.comptime { fields, get_field }
import from jaclang.scale.config.base_config { BaseConfig }

glob DATABASE_MODES = ('auto', 'provision', 'external', 'none');

def k8s_safe_slug(name: str, fallback: str = 'jaseci') -> str {
    import re;
    lowered = (name or '').strip().lower();
    slug = re.sub(r'[^a-z0-9-]+', '-', lowered);
    slug = re.sub(r'-+', '-', slug).strip('-');
    slug = slug[:63].strip('-');
    return slug or fallback;
}

def normalize_database_mode(raw: any) -> str {
    mode = str(raw or '').strip().lower() or 'auto';
    if mode not in DATABASE_MODES {
        raise ValueError(
            "[scale.kubernetes] database_mode must be one of "
            f"{', '.join(DATABASE_MODES)}, got {raw!r}."
        );
    }
    return mode;
}

def resolve_database_mode(config: dict[str, any]) -> str {
    mode = normalize_database_mode(config.get('database_mode'));
    if mode == 'auto' and config.get('postgres_enabled') is False {
        return 'none';
    }
    return mode;
}

obj KubernetesConfig(BaseConfig) {
    has container_port: int = 8000,
        database_mode: str = 'auto',
        database_url: str = '',
        database_namespace: str = '',
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
        revision_history_limit: int = 10,
        cpu_utilization_target: int = 50,
        memory_utilization_target: int = 80,
        autoscaler_engine: str = "hpa",
        autoscaler_scale_up_stabilization: int = 60,
        autoscaler_scale_up_max_pods: int = 2,
        idle_replicas: (int | None) = None,
        autoscaler_polling_interval: int = 30,
        autoscaler_cooldown: int = 300,
        autoscaler_initial_cooldown: int = 0,
        extra_triggers: list[dict] = [],
        http_activation: dict[str, any] = {},
        health_check_path: str = '/docs',
        python_image: str = '',
        wait_image: str = 'busybox',
        bundle_storage_class: str = '',
        bundle_access_mode: str = 'ReadWriteMany',
        resource_deletion_wait: int = 5,
        aws_nlb_wait: int = 60,
        app_mount_path: str = '/app',
        code_mount_path: str = '/code',
        workspace_path: str = '/code/workspace',
        additional_packages: list[str] = [],
        service_dependencies: list[str] = [],
        monitoring_enabled: bool = False,
        k8s_metrics_enabled: bool = True,
        loki_enabled: bool = False,
        tracing_enabled: bool = False,
        prometheus_admin_password: str = 'Adminpassword123',
        admin_username: str = 'admin',
        ingress_node_port: int = 30080,
        shared_ingress: bool = False,
        shared_ingress_class: str = 'nginx',
        shared_ingress_annotations: dict[str, str] = {},
        shared_ingress_tls: bool = False,
        shared_ingress_skip_reachability: bool = False,
        ingress_limit_rps: int = 20,
        ingress_limit_burst_multiplier: int = 5,
        ingress_limit_connections: int = 20,
        ingress_session_affinity: bool = True,
        domain: str = "",
        cert_manager_email: str = "",
        service_account_name: str = "",
        ops_console: bool = False,
        ops_console_mutations: bool = False,
        kube_context: str = "",
        kubeconfig: str = "",
        labels: dict[str, str] = {};

    def postinit {
        self.database_mode = normalize_database_mode(self.database_mode);
    }

    def database_enabled -> bool {
        return self.database_mode != 'none';
    }

    def database_deploy_intent(app_name: str) -> dict[str, any] {
        return {
            'app_name': app_name,
            'namespace': self.namespace,
            'database_mode': self.database_mode,
            'database_url': self.database_url,
            'database_namespace': self.database_namespace
        };
    }

    override def to_dict -> dict[str, any] {
        out: dict[str, any] = {};
        comptime for f in fields(KubernetesConfig) {
            out[f.name] = get_field(self, f.name);
        }
        return out;
    }

    static def from_dict(cls: type, config: dict[str, any]) -> KubernetesConfig {
        """A key absent from config is not passed, so the has-declaration above
        is the only place a default for it exists. The three assignments after
        the loop are the only fields whose value is not the config's verbatim.""";
        kw: dict[str, any] = {};
        comptime for f in fields(KubernetesConfig) {
            if f.name in config {
                kw[f.name] = config[f.name];
            }
        }
        kw['database_mode'] = resolve_database_mode(config);
        kw['database_url'] = str(config.get('database_url') or '');
        kw['database_namespace'] = str(config.get('database_namespace') or '');
        return cls(**kw);
    }
}
