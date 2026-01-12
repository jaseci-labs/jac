"""Application configuration model for deployments."""
import from pathlib { Path }

"""Configuration for an application deployment."""
class AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        build: bool = False,
        app_name: (str | None) = None,
        testing: bool = False;

    def get_code_path(self: AppConfig) -> Path {
        return Path(self.code_folder);
    }
}
