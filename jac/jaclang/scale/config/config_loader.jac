import from pathlib { Path }
import from jaclang.project.plugin_config { PluginConfigBase }
import logging;
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
    """True when jac.toml genuinely declares a [scale.microservices] section."""
    def microservices_declared(self: JacScaleConfig) -> bool;
}

glob logger = logging.getLogger(__name__),
     _scale_config_instance: JacScaleConfig | None = None;

def _ws_positive(ws_config: dict, key: str, fallback: (int | float)) -> float;
def get_scale_config(project_dir: Path | None = None) -> JacScaleConfig;
def reset_scale_config -> None;

"""Return a supported Redis eviction policy, falling back to allkeys-lru when invalid."""
def normalize_redis_eviction_policy(policy: str) -> str;

"""Clamp Redis eviction samples to the supported 1-10 range, defaulting to 5."""
def normalize_redis_eviction_samples(samples: int | str) -> int;

"""Resolve the bcrypt work factor from env override or config, clamped to bcrypt's valid 4..31 range."""
def resolve_password_hash_rounds(configured_rounds: int) -> int;
