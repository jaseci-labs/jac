import from jaclang.server { sv_client }

import from enum { StrEnum }


glob CONFIG_REVISION_ANNOTATION: str = "jac-scale.config-revision",
     _EXIT_CUSHION_S: int = 5,
     _CLIENT_BUILD_ATTEMPTS: int = 3,
     _CLIENT_BUILD_RETRY_PAUSE_S: int = 3,
     _CLIENT_BUILD_ALONGSIDE_SEAL_GIB: int = 24,
     _DEP_INSTALL_TIMEOUT_S: int = 900,
     _TRANSIENT_CLIENT_BUILD_MARKERS: tuple[str, ...] = (
         "dependency installation failed",
         "failed to install dependencies",
         "bun install failed",
         "econnreset",
         "econnrefused",
         "enotfound",
         "etimedout",
         "eai_again",
         "socket hang up",
         "i/o timeout",
         "network request failed",

     ),
     _VITE_BUILD_ENV_FILES: tuple[str, ...] = (
         ".env",
         ".env.local",
         ".env.production",
         ".env.production.local"
     ),
     _MEMBERSHIP_DIAGNOSIS_SHOWN: int = 3;


def _output_tail(result: any, lines: int = 15) -> str;


def _is_transient_client_build_failure(output: str) -> bool;


def client_build_alongside_seal -> bool;


enum ScalingMode(StrEnum) {
    NONE = "none",
    METRIC = "metric",
    HTTP_ACTIVATION = "http_activation"
}


def _membership_diagnosis(output: str, base: any, excluded: any) -> str;


def _vite_env_keys(base: any) -> dict[str, list[str]];


def pdb_spec(
    replica_floor: int, max_unavailable: int, min_available: (int | None) = None
) -> dict[str, any] | None;


def _is_named_list(items: list[object]) -> bool;


def merge_manifest_overlay(base: any, overlay: any) -> any;


def with_config_revision(manifest: dict[str, any], revision: str) -> dict[str, any];


obj ManifestBuilder {
    has k8s_config: KubernetesConfig,
        secrets: dict[str, str] = {},
        deploy_context: DeployContext = DeployContext(),
        logger: any = None,
        project_dir: str = "",
        _bundle_object_key: str = "",
        _toolchain_object_key: str = "",
        _pod_binary_sha256: str = "",
        fleet: (FleetSpec | None) = None,
        gateway_config: (dict[str, any] | None) = None,
        app_overrides: dict[str, dict[str, any]] = {},
        client_entry: (str | None) = None,
        dry_run: bool = False,
        _bundle_files_cache: (dict[str, str] | None) = None,
        _serve_config_cache: (ServeConfig | None) = None;

    def _gateway_cfg -> dict[str, any];
    def _project_config -> any;
    def _derive_fleet(app_config: AppConfig) -> FleetSpec;
    def _fleet(app_config: AppConfig) -> FleetSpec;
    def _injector_object_key -> str;
    def _prepare_injector(app_config: AppConfig) -> PvcInjector;
    def _install_app_deps(
        project_dir: str, jac_bin: str, env: (dict[str, str] | None)
    ) -> str;

    def _build_client_bundle(project_dir: str);
    def _start_client_build(project_dir: str) -> tuple[any, any];
    def _client_dist_candidates(stage: str, entry_rel: any) -> list[str];
    def generate_manifests(app_config: AppConfig, image: str) -> dict[str, any];
    def check_pod_config(app_config: AppConfig, image: str);
    def _check_deploy_settings_resolve;
    def _check_pod_config_resolves(
        deployments: dict[str, dict[str, any]], user_secret: dict[str, any] | None
    );

    def _pod_environ(
        container: dict[str, any], secret_keys: set[str]
    ) -> dict[str, str] | None;

    def _pod_tomls(
        base: any, excluded: any, toml_rel: str, toml_text: str, environ: dict[str, str]
    ) -> dict[str, str];

    def _nearest_nested_toml(nested: dict[str, str], sv_file: str) -> str;
    def generate_service_pod_specs(
        app_config: AppConfig, image: str
    ) -> dict[str, dict[str, any]];

    def _serve_config -> ServeConfig;
    def _shipped_config -> (JacConfig | None);
    def _drain_timeout -> int;
    def _signing_secret -> str;
    def _worker_count_env(svc_cfg: dict[str, any]) -> str;
    def _serve_env(svc_name: str, svc_cfg: dict[str, any]) -> list[dict[str, any]];
    def _service_config(svc_name: str) -> dict[str, any];
    def _bundle_files -> dict[str, str];
    def _declared_client_entry -> str;
    def _client_entry -> str;
    def _has_client_source -> bool;
    def _shared_volumes_config -> list[dict[str, any]];
    def _shared_volumes_for_service(
        svc_name: str
    ) -> tuple[list[dict[str, any]], list[dict[str, any]]];

    def _build_shared_pvc_manifests -> dict[str, dict[str, any]];
    def _build_user_secret_manifest -> dict[str, any] | None;
    def _user_secret_name -> str;
    def _owner_labels -> dict[str, str];
    def _service_account_name -> str;
    def _pod_service_account(svc_name: str) -> str;
    def _peer_dns_url(peer_name: str) -> str;
    def _build_env(svc_name: str, svc_cfg: dict[str, any]) -> list[dict[str, any]];
    def _configured_memory_request(svc_cfg: dict[str, any]) -> str | None;
    def _resolved_memory_request(svc_cfg: dict[str, any], is_gateway: bool) -> str;
    def _build_resources(
        svc_cfg: dict[str, any], is_gateway: bool = False
    ) -> dict[str, any];

    def _build_readiness_probe -> dict[str, any];
    def _build_liveness_probe -> dict[str, any];
    def _build_startup_probe -> dict[str, any];
    def _alb_deregistration_cushion -> int;
    def _build_prestop_hook -> dict[str, any];
    def _build_deployment_manifest(
        svc_name: str, pod_spec: dict[str, any]
    ) -> dict[str, any];

    def _build_service_manifest(svc_name: str) -> dict[str, any];
    def _resolve_scaling(
        svc_name: str, deployment: dict[str, any], service: dict[str, any]
    ) -> dict[str, any];

    def _canonical_rules_fingerprint(rules: list[dict[str, any]]) -> str;
    def _validate_http_activation_rules(scaling: dict[str, dict[str, any]]);
    def _get_autoscaler_config(svc_name: str) -> dict[str, any] | None;
    def _get_http_activation_config(svc_name: str) -> dict[str, any] | None;
    def _build_ingress_manifest(ingress_cfg: dict[str, any]) -> dict[str, any] | None;
    def _replica_floor(svc_name: str) -> int;
    def _build_pdb_manifest(
        svc_name: str, mode: (ScalingMode | None) = None
    ) -> dict[str, any] | None;

    def _pod_entrypoint -> dict[str, any];
    def _build_pod_spec(svc_name: str, image: str) -> dict[str, any];
    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, any];
    def _build_gateway_pod_spec(image: str) -> dict[str, any];
}
