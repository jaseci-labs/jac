import hashlib;
import json;
import os;
import from contextvars { ContextVar }
import from pathlib { Path }


obj WorkspaceResolution {
    has paths: dict[str, str] = {},
        workspaces: dict[str, WorkspaceSpec | None] = {};
}

glob _ws_cache: dict[str, tuple[tuple[float, ...], WorkspaceSpec]] = {},
     _resolution: ContextVar[WorkspaceResolution | None] = ContextVar(
         'jac_workspace_resolution', `default=None
     );

obj WorkspaceScope {
    has token: any = None;

    def __enter__ -> WorkspaceScope;
    def __exit__(exc_type: any, exc: any, trace: any) -> bool;
}

def workspace_scope -> WorkspaceScope;

def workspace_for_path(path: str) -> (WorkspaceSpec | None);
def _workspace_for_path(path: str) -> (WorkspaceSpec | None);
def app_for_path(path: str) -> (AppSpec | None);
def _fact_digest(app: AppSpec, ws_root: str) -> str;
def serving_apps(ws: WorkspaceSpec) -> list[AppSpec];
def _real(path: str) -> str;
def _npm_names_of(config: JacConfig) -> set[str];
def _chain_stamp(root_dir: str) -> tuple[float, ...];
def _implicit_kind(root_dir: str, kind: str) -> str;
def persistence_namespace(raw: any, project_name: str) -> str;
def _build_workspace(root_dir: str, toml_path: str, config: JacConfig) -> WorkspaceSpec;
