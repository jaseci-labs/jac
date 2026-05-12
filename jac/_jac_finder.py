"""Lazy ``.jac`` finder + opt-in path-level hook.

Registered via ``jaclang.pth`` at interpreter startup. On first ``.jac``
import, bootstraps jaclang and delegates to ``JacMetaImporter``. The
path-level hook (``_install_jac_path_hook``) is opt-in and only called
by the PyInstaller adapter — activating it at runtime would make tools
that inspect ``SOURCE_SUFFIXES`` try to AST-parse ``.jac`` as Python.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import os
import sys
from collections.abc import Sequence
from importlib.machinery import (
    BYTECODE_SUFFIXES,
    EXTENSION_SUFFIXES,
    SOURCE_SUFFIXES,
    ExtensionFileLoader,
    FileFinder,
    SourceFileLoader,
    SourcelessFileLoader,
)
from types import ModuleType

_JAC_SUFFIX = ".jac"


class _JacSourceFileLoader(SourceFileLoader):
    """Presents ``.jac`` files as empty Python source for build-time analyzers."""

    def get_source(self, fullname: str) -> str | None:  # type: ignore[override]
        if self.get_filename(fullname).endswith(_JAC_SUFFIX):
            return ""
        return super().get_source(fullname)


class _JacLazyFinder:
    """Meta-path stub that bootstraps jaclang on first ``.jac`` import."""

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        if "jaclang.meta_importer" in sys.modules:
            self._remove()
            return None

        parts = fullname.split(".")
        for base in path or sys.path:
            if not isinstance(base, str):
                continue
            candidate = os.path.join(base, *parts)
            if os.path.isfile(candidate + _JAC_SUFFIX) or (
                os.path.isdir(candidate)
                and os.path.isfile(os.path.join(candidate, "__init__" + _JAC_SUFFIX))
            ):
                return self._bootstrap_and_delegate(fullname, path, target)
        return None

    def _bootstrap_and_delegate(
        self,
        fullname: str,
        path: Sequence[str] | None,
        target: ModuleType | None,
    ) -> importlib.machinery.ModuleSpec | None:
        self._remove()
        import jaclang  # noqa: F401

        for finder in sys.meta_path:
            if type(finder).__name__ == "JacMetaImporter":
                return finder.find_spec(fullname, path, target)
        return None

    def _remove(self) -> None:
        with contextlib.suppress(ValueError):
            sys.meta_path.remove(self)


_JAC_PATH_HOOK_INSTALLED = False


def _install_jac_path_hook() -> None:
    """Replace the default ``FileFinder`` path hook with one that recognizes ``.jac``.

    Idempotent. Does not mutate ``SOURCE_SUFFIXES`` — we don't want tools
    that iterate that list to pick up ``.jac`` and try to AST-parse it.
    """
    global _JAC_PATH_HOOK_INSTALLED
    if _JAC_PATH_HOOK_INSTALLED:
        return

    new_hook = FileFinder.path_hook(
        (ExtensionFileLoader, EXTENSION_SUFFIXES),
        (_JacSourceFileLoader, [_JAC_SUFFIX]),
        (SourceFileLoader, SOURCE_SUFFIXES),
        (SourcelessFileLoader, BYTECODE_SUFFIXES),
    )

    for i, hook in enumerate(sys.path_hooks):
        if getattr(hook, "__name__", "") == "path_hook_for_FileFinder":
            sys.path_hooks[i] = new_hook
            break
    else:
        sys.path_hooks.insert(0, new_hook)

    sys.path_importer_cache.clear()
    _JAC_PATH_HOOK_INSTALLED = True


def install() -> None:
    """Register ``_JacLazyFinder`` on ``sys.meta_path`` if no Jac finder is present."""
    for f in sys.meta_path:
        if type(f).__name__ in ("JacMetaImporter", "_JacLazyFinder"):
            return
    sys.meta_path.insert(0, _JacLazyFinder())
