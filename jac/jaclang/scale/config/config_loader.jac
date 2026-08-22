import from pathlib { Path }
import from jaclang.project.plugin_config { PluginConfigBase }
import from jaclang.scale.config.firebase_env {
    FIREBASE_AUTH_PROJECT_ID_ENV,
    FIRESTORE_PROJECT_ID_ENV,
    resolve_firebase_project_id
}
import os;

class JacScaleConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacScaleConfig) -> str;
    override def get_default_config(self: JacScaleConfig) -> dict[str, any];
    override def get_config_schema(self: JacScaleConfig) -> dict[str, any];
    override def get_config_strict_env(self: JacScaleConfig) -> str;
    def get_jwt_config(self: JacScaleConfig) -> dict[str, any];
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
    def get_microservices_config(self: JacScaleConfig) -> dict[str, any];
}

def normalize_microservices_config(
    ms_config: dict[str, any], env_routes_fallback: bool = True
) -> dict[str, any];

glob _scale_config_instance: JacScaleConfig | None = None,
     _ms_enabled_deprecation_warned: bool = False;

def _ws_positive(ws_config: dict, key: str, fallback: (int | float)) -> float;
def get_scale_config(project_dir: Path | None = None) -> JacScaleConfig;
def peek_scale_config -> JacScaleConfig | None;
def reset_scale_config -> None;

def resolve_password_hash_cost(configured_cost: int) -> int;
