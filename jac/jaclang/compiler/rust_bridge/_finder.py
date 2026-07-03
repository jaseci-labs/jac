"""Resolve ``rust.<crate>`` to a compiled bridge shared library on disk.

Mirrors the CPython meta-importer's search order (rust_namespace.RustBridgeFinder)
so the na compiler step and the CPython importer agree on which ``.so`` a given
``import rust.<crate>`` refers to.  Layout resolved, in order:

  1. explicit ``extra_dirs``
  2. ``$JAC_RUST_BRIDGES_PATH`` (os.pathsep-separated) — dev/test override
  3. the jac cache:  <cache>/jac/rust-bridges/<crate>/<ver>/<target>/lib...
  4. dev fallback:   <cwd>/target/{release,debug} and <cwd>/../target/...
"""

from __future__ import annotations

import os
import platform
from pathlib import Path

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


def _search_dirs(crate: str, extra_dirs: list[str | Path] | None) -> list[Path]:
    dirs: list[Path] = [Path(d) for d in (extra_dirs or [])]

    env = os.environ.get("JAC_RUST_BRIDGES_PATH")
    if env:
        dirs += [Path(p) for p in env.split(os.pathsep) if p]

    # Cache: highest version dir under <root>/<crate>/, then <target>.
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


def find_bridge_lib(
    crate: str, extra_dirs: list[str | Path] | None = None
) -> Path | None:
    """Return the path to ``libjac_bridge_<crate>.<ext>`` or None if not found."""
    stems = _lib_stems(crate)
    for d in _search_dirs(crate, extra_dirs):
        for stem in stems:
            p = d / stem
            if p.is_file():
                return p
    return None
