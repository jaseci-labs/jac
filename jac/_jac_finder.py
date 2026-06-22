"""Lightweight lazy finder for .jac modules.

Registered via jaclang.pth at Python startup. Costs ~0ms for non-Jac Python.
On first .jac import, triggers ``import jaclang`` to bootstrap the full
compiler, then delegates to the real JacMetaImporter.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import os
import sys
from collections.abc import Sequence
from types import ModuleType

# The canonical extension registry lives in jaclang/jac0core/ext_registry.py.
# Importing it via the ``jaclang`` package would trigger the heavy
# ``jaclang/__init__`` bootstrap, defeating this lazy finder — so it is loaded
# by file path on first use and cached. This keeps the suffix lists in one
# place (issue #6858) without paying the bootstrap cost for non-Jac Python.
_registry: ModuleType | None = None


def _ext_registry() -> ModuleType:
    """Lazily load and cache the plain-Python extension registry by path."""
    global _registry
    if _registry is None:
        path = os.path.join(
            os.path.dirname(__file__), "jaclang", "jac0core", "ext_registry.py"
        )
        spec = importlib.util.spec_from_file_location("_jac_ext_registry", path)
        if spec is None or spec.loader is None:
            raise ImportError(f"cannot load extension registry from {path}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _registry = module
    return _registry


class _JacLazyFinder:
    """Stub meta-path finder that triggers full jaclang init on first .jac import."""

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        """Find spec for a module, bootstrapping jaclang on first .jac hit."""
        # Quick reject: if jaclang is already fully loaded, remove self
        if "jaclang.meta_importer" in sys.modules:
            self._remove()
            return None

        # Mirror JacMetaImporter: for a submodule import `path` already points
        # inside the parent package, so only the final name component is
        # appended; for a top-level import the full dotted name is used.
        if path is None:
            search_paths: Sequence[str] = sys.path
            module_parts = fullname.split(".")
        else:
            search_paths = list(path)
            module_parts = fullname.split(".")[-1:]

        for base in search_paths:
            if not isinstance(base, str):
                continue
            candidate = os.path.join(base, *module_parts)
            if os.path.isdir(candidate) and self._is_jac_package(candidate):
                return self._bootstrap_and_delegate(fullname, path, target)
            for suffix in _ext_registry().MODULE_SUFFIXES:
                if os.path.isfile(candidate + suffix):
                    return self._bootstrap_and_delegate(fullname, path, target)

        return None

    @classmethod
    def _is_jac_package(cls, directory: str) -> bool:
        """Return True if `directory` is a Jac package or Jac namespace package."""
        for init_name in _ext_registry().INIT_FILES:
            if os.path.isfile(os.path.join(directory, init_name)):
                return True
        # A directory with .jac files and no __init__.py is a Jac namespace
        # package; without claiming it, Python would own it as a plain one.
        if not os.path.isfile(os.path.join(directory, "__init__.py")):
            try:
                return any(e.endswith(".jac") for e in os.listdir(directory))
            except OSError:
                return False
        return False

    def _bootstrap_and_delegate(
        self,
        fullname: str,
        path: Sequence[str] | None,
        target: ModuleType | None,
    ) -> importlib.machinery.ModuleSpec | None:
        """Import jaclang to set up the real importer, then delegate."""
        self._remove()
        import jaclang  # noqa: F401

        # Find the real JacMetaImporter and delegate
        for finder in sys.meta_path:
            if type(finder).__name__ == "JacMetaImporter":
                return finder.find_spec(fullname, path, target)
        return None

    def _remove(self) -> None:
        """Remove self from sys.meta_path."""
        with contextlib.suppress(ValueError):
            sys.meta_path.remove(self)


def install() -> None:
    """Register the lazy finder if no Jac importer is already present."""
    for f in sys.meta_path:
        name = type(f).__name__
        if name in ("JacMetaImporter", "_JacLazyFinder"):
            return
    sys.meta_path.append(_JacLazyFinder())
