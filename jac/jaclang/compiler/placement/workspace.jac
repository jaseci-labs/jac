import fnmatch;
import hashlib;
import json;
import os;
import from jaclang.compiler.driver.modresolver { find_jac_project_root }

glob KIND_CODESPACE: dict[str, str] = {"js-package": "client"},
     KIND_HAS_SERVER: tuple = ("web-app", "service", "service-mesh"),
     KIND_UI: dict[str, str] = {
         "web-app": "dom",
         "web-static": "dom",
         "desktop": "dom",
         "js-package": "dom",
         "mobile": "mobui"
     },
     UI_MOBUI: str = "mobui",
     KIND_ENTRY: dict[str, str] = {"py-package": "lib.jac", "js-package": "lib.jac"},
     DEFAULT_ENTRY: str = "main.jac";

obj AppSpec {
    has name: str,
        kind: str = "",
        root_dir: str = "",
        `entry: str = "",
        file_rooted: bool = False,
        ui: str = "",
        platform: str = "",
        route: str = "",
        pins: dict[str, str] = {},
        own_pins: dict[str, str] = {},
        npm_names: set[str] = set(),
        has_server: bool = False,
        codespace: str = "",
        implicit: bool = False;

    def effective_route -> str;
    def contains(abs_path: str) -> bool;
    def claims_module(mod_dot: str) -> bool;
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
    def app_for_path(abs_path: str) -> (AppSpec | None);
    def owner_app_for_path(abs_path: str) -> tuple[(AppSpec | None), bool];
    def serving_apps -> list[AppSpec];
    def module_dot_path(abs_path: str) -> str;
}

glob _ws_cache: dict[str, tuple[tuple, WorkspaceSpec]] = {};

def kind_codespace(kind: str) -> str;
def kind_has_server(kind: str) -> bool;
def kind_entry(kind: str) -> str;
def kind_ui(kind: str) -> str {
    return KIND_UI.get(kind, '');
}

def workspace_for_path(path: str) -> (WorkspaceSpec | None);
def app_for_path(path: str) -> (AppSpec | None);
def owner_app_for_path(path: str) -> tuple[(AppSpec | None), bool];
def app_fact_digest(app: (AppSpec | None)) -> str;
def serving_apps(ws: WorkspaceSpec) -> list[AppSpec];
def _real(path: str) -> str;
def _read_toml(toml_path: str) -> dict;
def _table(raw: any, *keys: str) -> dict;
def _pins_of(raw: any) -> dict[str, str];
def _npm_names_of(raw: any) -> set[str];
def _chain_stamp(root_dir: str) -> tuple;
def _implicit_kind(root_dir: str, project: dict) -> str;
def _build_workspace(root_dir: str, toml_path: str, doc: dict) -> WorkspaceSpec;
