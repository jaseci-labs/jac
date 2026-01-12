"""Application configuration model for deployments."""
import from pathlib { Path }

"""Configuration for an application deployment."""
class AppConfig {
    has code_folder: str;
    has file_name: str = 'none';
    has build: bool = False;
    has app_name: (str | None) = None;
    has testing: bool = False;

    def get_code_path(self: AppConfig) -> Path {
        return Path(self.code_folder);
    }
}

