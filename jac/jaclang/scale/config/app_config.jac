import from pathlib { Path }
import from jaclang.scale.config.dev_config { DevDeploy }

obj AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        app_name: (str | None) = None,
        testing: bool = False,
        no_image: bool = False,
        dev: DevDeploy = DevDeploy();

    def get_code_path -> Path {
        return Path(self.code_folder);
    }
}
