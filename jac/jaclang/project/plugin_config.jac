import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }
import from jaclang.project.merge { deep_merge }

obj PluginConfigBase {
    has project_dir: Path | None = None,
        config_file: Path postinit,
        _config: dict[str, any] | None postinit,
        _jac_config: JacConfig | None postinit;

    def postinit -> None;
    def get_plugin_name -> str abst;
    def get_default_config -> dict[str, any] abst;
    def load -> dict[str, any];
    def get_jac_config -> JacConfig;
    def get_section(
        section: str, defaults: dict[(str, Any)] | None = None
    ) -> dict[str, any];

    def invalidate -> None;
}
