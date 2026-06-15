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

Platform roots (Linux examples; macOS uses ``~/Library/Caches`` and Windows
uses ``%LOCALAPPDATA%/jac/cache`` in place of ``~/.cache/jac``):
    JIR module cache:    ~/.cache/jac/jir/
    AI session store:    ~/.cache/jac/ai/

$XDG_CACHE_HOME is honored on Linux.
"""

import os
import sys
from pathlib import Path


def _platform_cache_base() -> Path:
    """The OS-appropriate cache base, before any ``jac/...`` suffix is applied.

    Shared by every global cache dir (JIR, bootstrap bytecode, AI sessions) so
    the win/darwin/linux resolution rule lives in exactly one place.
    """
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Caches"
    else:
        xdg = os.environ.get("XDG_CACHE_HOME")
        return Path(xdg) if xdg else (Path.home() / ".cache")


def get_jir_cache_dir() -> Path:
    """Return the platform-appropriate global cache directory for JIR files."""
    if sys.platform == "win32":
        # Windows nests under an extra 'cache' segment for parity with the
        # platform's AppData/.../cache convention.
        return _platform_cache_base() / "jac" / "cache" / "jir"
    return _platform_cache_base() / "jac" / "jir"


def get_ai_session_cache_dir() -> Path:
    """Return the global cache directory for ``jac ai`` conversation sessions.

    Sits alongside the JIR cache under the same platform-resolved root, so all
    of jac's on-disk caches live in one tree (see the cache centralization in
    #6709). Callers may honor a ``JAC_AI_CACHE`` env override on top of this
    default; this function owns only the platform default.
    """
    if sys.platform == "win32":
        return _platform_cache_base() / "jac" / "cache" / "ai"
    return _platform_cache_base() / "jac" / "ai"


def get_bootstrap_cache_dir() -> Path:
    """Global cache dir for marshalled jac0core bootstrap bytecode."""
    return get_jir_cache_dir() / "bootstrap"
