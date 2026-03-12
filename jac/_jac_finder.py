"""Lightweight lazy finder for .jac modules.

Registered via jaclang.pth at Python startup. Costs ~0ms for non-Jac Python.
On first .jac import, triggers ``import jaclang`` to bootstrap the full
compiler, then delegates to the real JacMetaImporter.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import os
import sys
from collections.abc import Sequence
from types import ModuleType


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

        # Check if any search path contains a matching .jac file or package
        parts = fullname.split(".")
        search_paths = list(path) if path else sys.path

        for base in search_paths:
            if not isinstance(base, str):
                continue
            candidate = os.path.join(base, *parts)
            if os.path.isfile(candidate + ".jac"):
                return self._bootstrap_and_delegate(fullname, path, target)
            if os.path.isdir(candidate) and os.path.isfile(
                os.path.join(candidate, "__init__.jac")
            ):
                return self._bootstrap_and_delegate(fullname, path, target)

        return None

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
