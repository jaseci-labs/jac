import hashlib;
import marshal;
import os;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import type from jaclang.compiler.frontend { unitree as uni }
glob _FORMAT: int = 9,
     SLOW_PREPARE_SECONDS: int = 45,
     _SKIP: set[str] = {'.jac', '.git', '.venv', 'venv', 'node_modules', '__pycache__'};

def _stamp(path: str, previous: any = None) -> tuple[int, int, str];

def _runtime_output(name: str) -> bool;

def _inventory(
    `root: any,
    inputs: bool = False,
    previous: (dict[str, tuple[int, int, str]] | None) = None
) -> dict[str, tuple[int, int, str]];

def _client_inventory(
    `root: str,
    dirs: list[str],
    files: list[str],
    previous: (dict[str, tuple[int, int, str]] | None) = None
) -> dict[str, tuple[int, int, str]];

def _digests(inventory: dict[str, tuple[int, int, str]]) -> dict[str, str];

def _identity -> tuple[str, str | None, str];

def _write(path: any, value: any);

def _sections(path: any, program: any) -> dict[int, bytes];

def _context_sections(path: any) -> dict[int, bytes];

def _project_modules(program: any, `root: any) -> dict[str, uni.Module];

def _semantic_metadata(revision: PreparedApplication, program: any);

obj ManifestSource {
    has path: str,
        app: str = '',
        persistence: any = None,
        edges: list[tuple[bool, str, list[str]]] = [],
        interop: any = None,
        client: any = None;
}

def _import_edges_of(rows: list[str]) -> list[tuple[bool, str, list[str]]];

def _tree_source(
    program: any, mod: uni.Module, imported: bool = True
) -> ManifestSource;

def _manifest(program: any, path: any, `root: any, mod: any = None) -> dict[str, any];

def build_manifest(
    `root: str,
    main: ManifestSource,
    lookup: Callable[[str], ManifestSource | None],
    project: list[ManifestSource]
) -> dict[str, any];

def _warn_private_declarations(application: PreparedApplication, console: any);


def _check(program: any, before: any);

def _prepare_sealed(
    `entry: str, program: any, image_root: str, entries: list[str]
) -> PreparedApplication;

def prepare_application(
    `entry: str,
    program: any,
    `root: (str | None) = None,
    services: any = (),
    client: bool = False,
    dev: (bool | None) = None,
    force_codespace: str = ''
) -> PreparedApplication;

def _release_compile_state(program: any);

def _capture_input(path: str, inputs: dict[str, str]);

def _prepare(
    `entry: any,
    program: any,
    `root: any,
    entries: any,
    client: any,
    dev: any,
    console: any
) -> PreparedApplication;

def _prepare_revision(
    `entry: any,
    program: any,
    `root: any,
    entries: any,
    client: any,
    dev: any,
    console: any,
    inputs: dict[str, str]
) -> PreparedApplication;

def prepare_route_metadata(`root: str, program: any) -> (list[str] | None);

def reprepare_application(
    application: PreparedApplication, program: any
) -> PreparedApplication;

def prepare_dynamic_module(
    path: str, program: any, application: PreparedApplication
) -> PreparedApplication;
