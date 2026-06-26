"""Application configuration model for deployments."""
import from pathlib { Path }

"""Configuration for an application deployment."""
obj AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        build: bool = False,
        app_name: (str | None) = None,
        testing: bool = False,
        experimental: bool = False,
        # Microservice no-image mode: copy local source into the cluster +
        # install jac at pod startup instead of building/pushing an image.
        no_image: bool = False;

    def get_code_path -> Path {
        return Path(self.code_folder);
    }
}
