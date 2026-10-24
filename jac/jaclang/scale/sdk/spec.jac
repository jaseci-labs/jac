import from pathlib { Path }

glob _RESOURCE_KEYS: list[str] = [
         'cpu_request',
         'cpu_limit',
         'memory_request',
         'memory_limit'
     ];


obj DeploySpec {
    has app_name: str,
        namespace: str = 'default',
        source: str = '',
        target: str = 'auto',
        secrets: dict[str, str] = {},
        env: dict[str, str] = {},
        domain: str = '',
        replicas: int = 1,
        resources: dict[str, str] = {},
        autoscaler: dict[str, any] = {},
        gateway: dict[str, any] = {},
        apps: dict[str, dict[str, any]] = {},
        app: str = '',
        kube_context: str = '',
        labels: dict[str, str] = {},
        extra: dict[str, any] = {};

    static def from_config(
        path: str, config: (dict[str, any] | None) = None
    ) -> DeploySpec;

    def resolved_target -> str;
    def resolve_entry -> tuple[str, str];
    def to_target_config -> dict[str, any];
    def to_gateway_config -> dict[str, any];
    def app_overrides -> dict[str, dict[str, any]];
}
