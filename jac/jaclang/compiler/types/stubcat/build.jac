import json;
import os;
import sys;
import time;

glob PRELUDE_ORDER: tuple[str, ...] = (
         "builtins",
         "typing",
         "types",
         "enum",
         "jac_builtins",
         "dom_types",
         "na_builtins",
         "js_globals",
         "builtin_overrides",
         "typing_ambient"
     );

def parse_versions(stdlib_dir: str) -> dict[str, tuple[int, int]];

def _minor_of(text: str) -> int;

def version_ok(dotted: str, versions: dict[str, tuple[int, int]], minor: int) -> bool;

def typeshed_module_files(stdlib_dir: str, minor: int) -> list[tuple[str, str]];

def jac_internal_stub_files(pkg_dir: str) -> list[tuple[str, str]];

def _rss_mb -> int;

def build_catalog(
    out_path: str,
    only: (list[str] | None) = None,
    pkg_dir: (str | None) = None,
    quiet: bool = False
) -> dict[str, any];

def _build_catalog_inner(
    prog: JacProgram,
    out_path: str,
    only: (list[str] | None),
    pkg_dir: (str | None),
    quiet: bool,
    started: float
) -> dict[str, any];

def _cached_catalog(pkg_dir: (str | None)) -> str;

def _keep_catalog(out: str, cached: str);

def main(argv: list[str]) -> int;
