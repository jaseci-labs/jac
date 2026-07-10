import from pathlib { Path }
import from jaclang.scale.config.dev_config { Channel }

obj AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        app_name: (str | None) = None,
        testing: bool = False,
        no_image: bool = False,
        channel: Channel = Channel.STABLE;

    def get_code_path -> Path {
        return Path(self.code_folder);
    }
}
