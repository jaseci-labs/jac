import os;

obj AppSpec {
    has name: str,
        kind: str = "",
        `entry: str = "",
        ui: str = "",
        platform: str = "",
        route: str = "",
        pins: dict[str, str] = {},
        npm_names: set[str] = set(),
        has_server: bool = False,
        codespace: str = "",
        implicit: bool = False,
        real_entry: str = "",
        fact_digest: str = "";

    def effective_route -> str;
}

obj WorkspaceSpec {
    has project_root: str,
        toml_path: str,
        apps: dict[str, AppSpec] = {},
        default_app: str = "",
        explicit: bool = False,
        digest: str = "",
        base_pins: dict[str, str] = {},
        base_npm_names: set[str] = set();

    def app(name: str) -> (AppSpec | None);
    def app_at(real_path: str) -> (AppSpec | None);
    def app_for_path(abs_path: str) -> (AppSpec | None);
    def serving_apps -> list[AppSpec];
}

def normalized_path(path: str) -> str {
    return os.path.normcase(os.path.realpath(os.path.abspath(path)));
}
