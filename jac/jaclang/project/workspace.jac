import fnmatch;
import hashlib;
import json;
import os;
import from collections.abc { Iterator }
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from jaclang.project.modresolver { find_jac_project_root }

import from jaclang.project.app_kinds {
    kind_codespace,
    kind_has_server,
    kind_entry,
    kind_ui,
    UI_MOBUI
}

import from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }

obj WorkspaceResolution {
    has paths: dict[str, str] = {},
        workspaces: dict[str, WorkspaceSpec | None] = {};
}

glob _ws_cache: dict[str, tuple[tuple[float, ...], WorkspaceSpec]] = {},
     _resolution: ContextVar[WorkspaceResolution | None] = ContextVar(
         'jac_workspace_resolution', `default=None
     );

@contextmanager
def workspace_scope -> Iterator[None] {
    if _resolution.get() is not None {
        yield ;
        return;
    }
    token = _resolution.set(WorkspaceResolution());
    try {
        yield ;
    } finally {
        _resolution.reset(token);
    }
}

def workspace_for_path(path: str) -> (WorkspaceSpec | None);
def _workspace_for_path(path: str) -> (WorkspaceSpec | None);
def app_for_path(path: str) -> (AppSpec | None);
def _fact_digest(app: AppSpec, ws_root: str) -> str;
def serving_apps(ws: WorkspaceSpec) -> list[AppSpec];
def _real(path: str) -> str;
def _read_toml(toml_path: str) -> dict[str, any];
def _table(raw: any, *keys: str) -> dict[str, any];
def _pins_of(raw: any) -> dict[str, str];
def _npm_names_of(raw: any) -> set[str];
def _chain_stamp(root_dir: str) -> tuple[float, ...];
def _implicit_kind(root_dir: str, project: dict[str, any]) -> str;
def _build_workspace(
    root_dir: str, toml_path: str, doc: dict[str, any]
) -> WorkspaceSpec;
