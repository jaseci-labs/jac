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
    def get_jwt_config(self: JacScaleConfig) -> dict[str, any];
    def get_sso_config(self: JacScaleConfig) -> dict[str, any];
    def get_database_config(self: JacScaleConfig) -> dict[str, any];
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

glob _scale_config_instance: JacScaleConfig | None = None;

def _ws_positive(ws_config: dict, key: str, fallback: (int | float)) -> float;
def get_scale_config(project_dir: Path | None = None) -> JacScaleConfig;
def reset_scale_config -> None;
