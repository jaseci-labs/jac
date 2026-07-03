"""M3 CPython consumer: the ``rust.`` namespace meta-importer.

Makes ``import rust.regex { Regex }`` work on the CPython runtime with no
generated files. Resolves ``rust.<crate>`` to a compiled bridge library from the
jac cache layout, reads the D2 metadata (never dlopen'd for the *metadata* — the
section is parsed as bytes; the library is only dlopen'd to call its functions),
hard-fails on an unsupported ABI version, then materializes the module via the
shared codegen used everywhere else (`build_module`).

Layout resolved, in order:
  1. explicit ``search_dirs`` passed to install_rust_namespace()
  2. ``$JAC_RUST_BRIDGES_PATH`` (os.pathsep-separated dirs) — dev/test override
  3. the jac cache:  ~/.cache/jac/rust-bridges/<name>/<ver>/<target>/lib...
  4. dev fallback:   <cwd>/target/{release,debug} and <cwd>/../target/...

Version skew is structurally impossible (D5): the metadata travels inside the
library it describes, so there is no separate bindings file to drift.
"""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import os
import platform
import sys
import types as pytypes
from collections.abc import Sequence
from pathlib import Path

from ._blob import parse
from ._codegen import build_module
from ._elf import read_jac_bridge_section

__all__ = ["install_rust_namespace", "RustBridgeFinder", "SUPPORTED_ABI"]

RUST_PREFIX = "rust."
SUPPORTED_ABI = 1

_STEMS = ("lib{}.so", "lib{}.dylib", "{}.dll")


def _target_triple() -> str:
    """Best-effort host target triple for the cache <target> segment."""
    machine = platform.machine().lower()
    arch = {
        "x86_64": "x86_64",
        "amd64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64",
    }.get(machine, machine)
    sysname = platform.system()
    if sysname == "Linux":
        return f"{arch}-unknown-linux-gnu"
    if sysname == "Darwin":
        return f"{arch}-apple-darwin"
    if sysname == "Windows":
        return f"{arch}-pc-windows-msvc"
    return f"{arch}-unknown-{sysname.lower()}"


def _cache_root() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "jac" / "rust-bridges"


def _lib_stems(crate: str) -> list[str]:
    return [s.format(f"jac_bridge_{crate}") for s in _STEMS]


class RustBridgeFinder(importlib.abc.MetaPathFinder):
    """Resolve ``rust`` (namespace package) and ``rust.<crate>`` (bridge lib)."""

    def __init__(self, extra_dirs: list[str | Path] | None = None) -> None:
        self._extra = [Path(d) for d in (extra_dirs or [])]

    # -- directory resolution -------------------------------------------------

    def _search_dirs(self, crate: str) -> list[Path]:
        dirs: list[Path] = list(self._extra)

        env = os.environ.get("JAC_RUST_BRIDGES_PATH")
        if env:
            dirs += [Path(p) for p in env.split(os.pathsep) if p]

        # Cache: pick the highest version dir under <root>/<crate>/, then <target>.
        crate_root = _cache_root() / crate
        if crate_root.is_dir():
            versions = sorted(
                (d for d in crate_root.iterdir() if d.is_dir()),
                key=lambda d: d.name,
                reverse=True,
            )
            triple = _target_triple()
            for v in versions:
                dirs.append(v / triple)
                dirs.append(v)  # flat layout tolerated

        # Dev fallback: the cargo workspace target dir.
        cwd = Path.cwd()
        for base in (cwd, cwd.parent):
            dirs += [base / "target" / "release", base / "target" / "debug"]

        return dirs

    def _find_lib(self, crate: str) -> Path | None:
        stems = _lib_stems(crate)
        for d in self._search_dirs(crate):
            for stem in stems:
                p = d / stem
                if p.is_file():
                    return p
        return None

    # -- MetaPathFinder protocol ----------------------------------------------

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: pytypes.ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        if fullname == "rust":
            spec = importlib.machinery.ModuleSpec(
                fullname, loader=None, is_package=True
            )
            spec.submodule_search_locations = []
            return spec
        if not fullname.startswith(RUST_PREFIX):
            return None
        crate = fullname[len(RUST_PREFIX) :]
        if "." in crate:  # rust.<crate>.<sub> is not a bridge module
            return None
        lib = self._find_lib(crate)
        if lib is None:
            return None
        return importlib.machinery.ModuleSpec(
            fullname, _RustBridgeLoader(str(lib), crate), origin=str(lib)
        )


class _RustBridgeLoader(importlib.abc.Loader):
    def __init__(self, so_path: str, crate: str) -> None:
        self._so = so_path
        self._crate = crate

    def create_module(self, spec):  # noqa: ANN001
        return None

    def exec_module(self, module: pytypes.ModuleType) -> None:
        blob = read_jac_bridge_section(self._so)
        meta = parse(blob)
        if meta.abi_version != SUPPORTED_ABI:
            raise ImportError(
                f"rust.{self._crate}: bridge '{self._so}' declares ABI version "
                f"{meta.abi_version}, but this jac supports v{SUPPORTED_ABI}. "
                "Rebuild the bridge or upgrade jac."
            )
        built = build_module(self._so, meta)
        module.__dict__.update(
            {k: v for k, v in built.__dict__.items() if not k.startswith("__")}
        )
        module.__file__ = self._so
        module.__package__ = module.__name__


def install_rust_namespace(
    search_dirs: list[str | Path] | None = None,
) -> RustBridgeFinder:
    """Install the ``rust.`` meta-importer on sys.meta_path (idempotent)."""
    for f in sys.meta_path:
        if isinstance(f, RustBridgeFinder):
            return f
    finder = RustBridgeFinder(search_dirs)
    sys.meta_path.append(finder)
    return finder
