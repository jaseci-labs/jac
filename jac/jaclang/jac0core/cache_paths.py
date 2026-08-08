"""Single source of truth for jac's global on-disk cache root.

Pure Python with no jac dependencies, so it is importable during bootstrap —
before the jac0core ``.jac`` modules have been transpiled. Both the bootstrap
bytecode cache (``meta_importer``) and the JIR module cache
(``jaclang.jac0core.jir``) derive their directories from here, so the
platform-resolution logic lives in exactly one place.

This module owns only the genuinely global, config-independent directories.
The per-module cache locations (``jir/modules/`` and its ``native/`` subdir)
are project-aware and therefore resolved in ``jaclang.jac0core.jir`` via
``get_module_cache_path``/``get_native_cache_dir(source_path)``, which fall
back to the project's ``.jac/cache`` when inside a project.

Platform roots:
    Linux:   ~/.cache/jac/jir/             ($XDG_CACHE_HOME honored)
    macOS:   ~/Library/Caches/jac/jir/
    Windows: %LOCALAPPDATA%/jac/cache/jir/
"""

import os
import sys
from pathlib import Path


def get_jir_cache_dir() -> Path:
    """Return the platform-appropriate global cache directory for JIR files."""
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache" / "jir"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac" / "jir"
    else:
        xdg = os.environ.get("XDG_CACHE_HOME")
        base = Path(xdg) if xdg else (Path.home() / ".cache")
        return base / "jac" / "jir"


def get_bootstrap_cache_dir() -> Path:
    """Global cache dir for marshalled jac0core bootstrap bytecode."""
    return get_jir_cache_dir() / "bootstrap"


# jaclang package root (parent of jac0core/).  Pure-Python so jir.jac and
# meta_importer can consult it before jac0core is transpiled.
_JACLANG_PKG_DIR = str(Path(__file__).resolve().parent.parent)
_JAC0CORE_DIR = str(Path(__file__).resolve().parent)


def is_bootstrap_jac_path(source_path: str) -> bool:
    """True for jac0-tier .jac sources compiled by jac0 during bootstrap."""
    resolved = str(Path(source_path).resolve())
    return resolved.endswith(".jac") and resolved.startswith(_JAC0CORE_DIR + os.sep)


def is_jac_lazy_eligible(source_path: str) -> bool:
    """True when a .jac module may use lazy chunked JIR (user deps only).

    Excludes jac0core bootstrap modules and the jaclang self-hosting tree so
    enabling JAC_LAZY_JAC globally does not cascade lazy hydration across the
    ~165 interdependent compiler modules (which OOMs under memory pressure).
    """
    resolved = str(Path(source_path).resolve())
    if not resolved.endswith(".jac") or resolved.endswith(".na.jac"):
        return False
    if is_bootstrap_jac_path(resolved):
        return False
    if resolved.startswith(_JACLANG_PKG_DIR + os.sep):
        return False
    return True


def get_app_cache_dir() -> Path:
    """Global cache dir for materialized app bundles (.jab), content-keyed."""
    return get_jir_cache_dir().parent / "apps"
