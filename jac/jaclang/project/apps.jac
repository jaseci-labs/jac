import os;

glob APP_TABLE_KEYS: tuple[str, ...] = (
         "kind",
         "entry_point",
         "platform",
         "route"
     ),
     REMOVED_APP_KEYS: dict[str, str] = {
         "path": "apps are identified by entry-point; use entry-point = \"directory.main\"",
         "client": (
             "the kind decides the client (web-app and web-static render the DOM, "
             "desktop wraps it in a webview, mobile is React Native); "
             "build a mobile app for a browser with --platform web"
         ),
         "client_kind": "every mobile app is mobUI; the kind decides the UI vocabulary"
     };

obj AppConfig {
    has name: str,
        kind: str,
        entry_point: str = "",
        platform: str = "",
        route: str = "",
        overlays: dict[str, any] = {},
        implicit: bool = False;

    def entry_path(project_root: str) -> str;
    def effective_route -> str;
    def ui -> str;
    def contains(project_root: str, abs_path: str) -> bool;
}

def validate_app_name(name: str) -> None;

def validate_entry_point(module: str) -> str;

def resolve_entry_path(module: str, project_root: str) -> str;

def parse_apps(project_data: dict, apps_data: dict) -> dict[str, AppConfig];

def implicit_app(config: any) -> AppConfig;

def _norm_path(path: str) -> str;
