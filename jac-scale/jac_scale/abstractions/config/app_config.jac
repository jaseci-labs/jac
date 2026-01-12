"""Application configuration model for deployments."""
import from pathlib { Path }

"""Configuration for an application deployment."""
class AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        build: bool = False,
        app_name: (str | None) = None,
        testing: bool = False;

    def init(
        self: AppConfig,
        code_folder: str,
        file_name: str = 'none',
        build: bool = False,
        app_name: (str | None) = None,
        testing: bool = False
    ) -> None {
        self.code_folder = code_folder;
        self.file_name = file_name;
        self.build = build;
        self.app_name = app_name;
        self.testing = testing;
    }

    def get_code_path(self: AppConfig) -> Path {
        return Path(self.code_folder);
    }
}
