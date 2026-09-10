import fnmatch;
import hashlib;
import json;
import os;
import from jaclang.compiler.driver.modresolver { find_jac_project_root }

import from jaclang.project.app_kinds {
    kind_codespace,
    kind_has_server,
    kind_entry,
    kind_ui,
    UI_MOBUI
}

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
        implicit: bool = False;

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
    def app_for_path(abs_path: str) -> (AppSpec | None);
    def serving_apps -> list[AppSpec];
    def module_dot_path(abs_path: str) -> str;
}

glob _ws_cache: dict[str, tuple[tuple, WorkspaceSpec]] = {};

def workspace_for_path(path: str) -> (WorkspaceSpec | None);
def app_for_path(path: str) -> (AppSpec | None);
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
