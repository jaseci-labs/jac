import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }

def deep_merge(base: dict[str, any], override_dict: dict[str, any]) -> dict[str, any];

obj PluginConfigBase {
    has project_dir: Path | None = None,
        config_file: Path by postinit,
        _config: dict[str, any] | None by postinit,
        _jac_config: JacConfig | None by postinit;

    def postinit -> None;
    def get_plugin_name -> str abs;
    def get_default_config -> dict[str, any] abs;
    def load -> dict[str, any];
    def get_jac_config -> JacConfig;
    def get_section(
        section: str, defaults: dict[(str, Any)] | None = None
    ) -> dict[str, any];

    def invalidate -> None;
}
