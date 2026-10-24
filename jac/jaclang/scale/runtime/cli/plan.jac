import yaml;


def _diags_for(diagnostics: list[Diagnostic], service: str | None) -> list[Diagnostic];


def _print_diag(d: Diagnostic, indent: str = "    ");


def _resource_range(req: str | None, lim: str | None) -> str;


obj HPAView {
    has min_replicas: int,
        max_replicas: int,
        cpu_target: int;

    static def from_manifest(hpa: any) -> HPAView | None;
}


obj HTTPActivationView {
    has min_replicas: int,
        max_replicas: int,
        metric: str;

    static def from_manifest(http: Any) -> HTTPActivationView | None;
}


obj PDBView {
    has max_unavailable: int | None;

    static def from_manifest(pdb: any) -> PDBView | None;
}


obj ServiceView {
    has name: str,
        image: str,
        replicas: int,
        cpu_request: str | None = None,
        cpu_limit: str | None = None,
        mem_request: str | None = None,
        mem_limit: str | None = None,
        container_port: int | None = None,
        route_path: str | None = None,
        env_keys: list[str] = [],
        secret_ref_count: int = 0,
        hpa: HPAView | None = None,
        http_activation: HTTPActivationView | None = None,
        pdb: PDBView | None = None,
        mounts: list[tuple[str, str]] = [];

    static def from_manifests(
        name: str,
        deployment: any,
        hpa: any,
        http_activation: any,
        pdb: any,
        route_path: str | None
    ) -> ServiceView;

    def render(diagnostics: list[Diagnostic]);
}


obj IngressRuleView {
    has host: str,
        paths: list[tuple[str, str]];
}


obj IngressView {
    has rules: list[IngressRuleView];

    static def from_manifest(
        ingress: any, routes: dict[str, any]
    ) -> IngressView | None;

    def render;
}


def _render_cluster_wide(bundle: any, gateway_cfg: any) -> None;


def _render_totals(bundle: any);


obj Plan {
    has bundle: dict[str, any],
        routes: dict[str, any],
        gateway_cfg: dict[str, any],
        svc_configs: dict[str, any],
        cluster_type: str,
        namespace: str,
        services: list[ServiceView],
        ingress: IngressView | None;

    static def from_target(target: any, app_config: AppConfig) -> Plan;
    def validate -> list[Diagnostic];
    def render(diagnostics: list[Diagnostic], show_yaml: bool = False);
    def _render_header(diagnostics: list[Diagnostic]);
    def _render_global_diags(diagnostics: list[Diagnostic]) -> None;
    def _render_services(diagnostics: list[Diagnostic]) -> None;
    def _render_yaml_or_hint(show_yaml: bool);
    def _flatten_manifests -> list[dict[str, any]];
}


def print_plan(
    target: any, app_config: AppConfig, show_yaml: bool = False
) -> tuple[dict[str, any], list[Diagnostic]];
