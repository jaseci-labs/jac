"""
jac_bridge_loader — auto-generate Python ctypes bindings from jac-bridge .so files.

Public API
----------
load_bridge(so_path)  ->  types.ModuleType
    Open a jac-bridge .so, parse the embedded D2 metadata, return a ready-to-use
    Python module with one class per opaque Rust type and one exception class per
    error type.

install_finder(search_dirs=None)
    Install a sys.meta_path hook so that ``import jac_bridge_<mod>`` automatically
    locates and loads ``libjac_bridge_<mod>.so`` from the search path.

Example
-------
    from jac_bridge_loader import load_bridge

    regex = load_bridge("bridges/target/release/libjac_bridge_regex.so")
    re = regex.Regex(r"foo\\d+")
    assert re.is_match("foo42")
    re.close()
"""

from __future__ import annotations

import sys
import types as pytypes
from pathlib import Path

from ._blob import parse
from ._codegen import build_module
from ._elf import read_jac_bridge_section
from .rust_namespace import RustBridgeFinder, install_rust_namespace

__all__ = [
    "load_bridge",
    "install_finder",
    "install_rust_namespace",
    "RustBridgeFinder",
]


def load_bridge(so_path: str | Path) -> pytypes.ModuleType:
    so_path = str(so_path)
    blob = read_jac_bridge_section(so_path)
    meta = parse(blob)
    return build_module(so_path, meta)


def install_finder(search_dirs: list[str | Path] | None = None) -> None:
    from ._finder import JacBridgeFinder

    finder = JacBridgeFinder(search_dirs or [])
    if not any(isinstance(f, JacBridgeFinder) for f in sys.meta_path):
        sys.meta_path.append(finder)
