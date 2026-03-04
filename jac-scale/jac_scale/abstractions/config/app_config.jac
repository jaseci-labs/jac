"""Application configuration model for deployments."""
import from pathlib { Path }

"""Configuration for an application deployment."""
obj AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        build: bool = False,
        app_name: (str | None) = None,
        testing: bool = False,
        experimental: bool = False;

    def get_code_path -> Path {
        return Path(self.code_folder);
    }
}
