import from pathlib { Path }
import from jaclang.project.plugin_config { PluginConfigBase }
import from jaclang.scale.config.firebase_env {
    FIREBASE_AUTH_PROJECT_ID_ENV,
    FIRESTORE_PROJECT_ID_ENV,
    resolve_firebase_project_id
}
import os;

glob APP_SCALE_KEYS: tuple = (
         "rpc_timeout",
         "http_forward_timeout",
         "replicas",
         "cpu_request",
         "cpu_limit",
         "memory_request",
         "memory_limit",
         "env",
         "hpa",
         "pdb",
         "deployment_overlay",
         "triggers",
         "http_activation",
         "read_cache",
         "workers",
         "threads"
     ),
     GATEWAY_POD_KEYS: tuple = (
         "replicas",
         "cpu_request",
         "cpu_limit",
         "memory_request",
         "memory_limit",
         "env",
         "hpa",
         "pdb",
         "deployment_overlay"
     ),
     GATEWAY_BOOT_KEYS: tuple = (
         "boot_health_timeout",
         "boot_max_wait",
         "health_monitor_interval",
         "route_refresh_seconds"
     );

class JacScaleConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacScaleConfig) -> str;
    override def get_default_config(self: JacScaleConfig) -> dict[str, any];
    override def get_config_schema(self: JacScaleConfig) -> dict[str, any];
    override def get_config_strict_env(self: JacScaleConfig) -> str;
    def get_sso_config(self: JacScaleConfig) -> dict[str, any];
    def get_database_config(self: JacScaleConfig) -> dict[str, any];
    def get_deploy_database_config(self: JacScaleConfig) -> dict[str, any];
    def get_kubernetes_config(self: JacScaleConfig) -> dict[str, any];
    def get_server_config(self: JacScaleConfig) -> dict[str, any];
    def get_webhook_config(self: JacScaleConfig) -> dict[str, any];
    def get_secrets_config(self: JacScaleConfig) -> dict[str, str];
    def get_monitoring_config(self: JacScaleConfig) -> dict[str, any];
    def get_events_config(self: JacScaleConfig) -> dict[str, any];
    def get_websocket_config(self: JacScaleConfig) -> dict[str, any];
    def get_admin_config(self: JacScaleConfig) -> dict[str, any];
    def get_scheduler_config(self: JacScaleConfig) -> dict[str, any];
    def get_telemetry_config(self: JacScaleConfig) -> dict[str, any];
    def get_emailer_config(self: JacScaleConfig) -> dict[str, any];
    def get_auth_config(self: JacScaleConfig) -> dict[str, any];
    def get_gateway_config(self: JacScaleConfig) -> dict[str, any];
    def get_app_scale_config(self: JacScaleConfig, app_name: str) -> dict[str, any];
}

def normalize_gateway_config(gateway_config: dict[str, any] | None) -> dict[str, any];

def app_scale_overrides(config: any, app_name: str) -> dict[str, any];

def _pick_app_scale_keys(section: dict[str, any] | None) -> dict[str, any];


glob _scale_config_instance: JacScaleConfig | None = None,
     _app_scale_cache: dict[str, dict[str, any]] = {},
     _prometheus_namespace_warned: bool = False;

def sanitize_prometheus_namespace(name: str) -> str;
def _resolve_prometheus_namespace(configured: str | None, k8s_namespace: str) -> str;
def _ws_positive(ws_config: dict, key: str, fallback: (int | float)) -> float;
def get_scale_config(project_dir: Path | None = None) -> JacScaleConfig;
def peek_scale_config -> JacScaleConfig | None;
def reset_scale_config -> None;
