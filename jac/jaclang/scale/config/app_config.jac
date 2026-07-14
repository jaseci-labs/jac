import from pathlib { Path }

obj AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        app_name: (str | None) = None,
        testing: bool = False,
        no_image: bool = False;

    def get_code_path -> Path {
        return Path(self.code_folder);
    }
}
