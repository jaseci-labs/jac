glob STRICT_ENV: str = "JAC_SCALE_CONFIG_STRICT";

def known_deploy_targets -> list[str];
def scale_schema_options -> dict[str, any];
def validate_scale_config(raw: dict[str, any] | None) -> list[str];
def _declared_target_findings(raw: dict[str, any]) -> list[str];
