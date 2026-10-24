obj KubernetesTargetBase(DeploymentTarget) {
    has config: KubernetesConfig,
        logger: (Logger | None) = None,
        k8s_config: KubernetesConfig postinit,
        env_list: list[any] = [],
        secrets: dict[str, str] = {},
        env: dict[str, str] = {},
        events: EventSink = NoopSink(),
        dry_run: bool = False;

    def postinit;
    def _emit(
        phase: str,
        status: str,
        message: str,
        step: str = "",
        detail: dict[str, any] = {}
    );

    def _owner_labels -> dict[str, str];
    def _load_cluster_config;
    def _get_database_init_containers(app_name: str) -> list[dict[(str, any)]];
    def _deploy_databases(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _apply_provider_service_account(
        sa_spec: dict[str, any], namespace: str, core_v1: any
    );

    def get_status(app_name: str) -> ResourceStatusInfo;
    def scale(app_name: str, replicas: int);
    def _get_lb_endpoint(app_name: str) -> (str | None);
    def port_forward_hint -> str;
    def get_service_url(app_name: str) -> (str | None);
    def enable_tls(app_name: str);
    def get_full_status(app_name: str) -> dict[str, any];
}
