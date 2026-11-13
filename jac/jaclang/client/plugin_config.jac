import from pathlib { Path }


class JacClientPluginConfig {
    static def get_plugin_metadata -> dict[str, any];
    static def get_config_schema -> dict[str, any];
    static def register_ecosystem_providers -> list[EcosystemProvider];
    static def client_project_templates -> list[dict[str, any]];
}

def _load_template(template_name: str) -> dict[str, any] | None;
