"""Single source of truth for jac's global on-disk cache root.

Pure Python with no jac dependencies, so it is importable during bootstrap,
before the jac0core ``.jac`` modules have been transpiled. Everything that
writes under the machine-wide cache derives its directory from here: the
bootstrap bytecode cache (``meta_importer``) and the JIR module cache
(``jaclang.compiler.driver.jir``) directly, every other bucket through the
``jaclang.cache`` authority, which wraps this rule rather than restating it.
The fused launcher (``jaclang/dist/fused/materialize.jac``) runs before
CPython exists and carries an equivalent copy; ``tests/cache`` holds the two
to the same answers.

The root rule::

    JAC_CACHE_HOME            an explicit root (``~`` expands)
    XDG_CACHE_HOME/jac        the XDG base, on every platform when set
    Linux:   ~/.cache/jac
    macOS:   ~/Library/Caches/jac
    Windows: %LOCALAPPDATA%/jac/cache

This module owns only the genuinely global, config-independent directories.
The per-module cache locations (``jir/modules/`` and its ``native/`` subdir)
are project-aware and therefore resolved in ``jaclang.compiler.driver.jir`` via
``get_module_cache_path``/``get_native_cache_dir(source_path)``, which fall
back to the project's ``.jac/cache`` when inside a project.
"""

import os
import sys
from pathlib import Path


def get_cache_home() -> Path:
    """Return the root of jac's machine-wide cache (see the module docstring)."""
    explicit = os.environ.get("JAC_CACHE_HOME", "").strip()
    if explicit:
        return Path(os.path.expanduser(explicit))
    xdg = os.environ.get("XDG_CACHE_HOME", "").strip()
    if xdg:
        return Path(xdg) / "jac"
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac"
    return Path.home() / ".cache" / "jac"


def get_jir_cache_dir() -> Path:
    """Return the global cache directory for JIR files."""
    return get_cache_home() / "jir"


def get_bootstrap_cache_dir() -> Path:
    """Global cache dir for marshalled jac0core bootstrap bytecode."""
    return get_jir_cache_dir() / "bootstrap"
