"""Lightweight lazy finder for .jac modules.

Registered via ``jaclang.pth`` at Python startup. Costs ~0 ms for non-Jac
Python. On first ``.jac`` import, triggers ``import jaclang`` to bootstrap
the full compiler, then delegates to the real ``JacMetaImporter``.

Also provides an **opt-in** path-level ``.jac`` hook
(``_install_jac_path_hook``) for build-time tools that bypass
``sys.meta_path`` and go straight to ``importlib``'s path machinery —
notably PyInstaller's analyzer. The hook is *not* called by ``install()``:
activating it at runtime would make pytest's assertion rewriter and
similar tooling try to AST-parse ``.jac`` source as Python. The PyInstaller
adapter in ``jaclang._pyinstaller`` is the only caller.
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
    """SourceFileLoader that presents .jac files as empty Python at analysis time.

    Python's FileFinder calls ``get_source`` during normal and static
    analysis (PyInstaller's modulegraph, setuptools, etc.). Jac syntax
    won't compile as Python, so we return an empty string — enough to
    register the module in build-tool graphs and preserve its file
    association. Actual Jac compilation happens at runtime via
    ``JacMetaImporter``, which sits ahead of the path-based finder on
    ``sys.meta_path``.
    """

    def get_source(self, fullname: str) -> str | None:  # type: ignore[override]
        path = self.get_filename(fullname)
        if path.endswith(_JAC_SUFFIX):
            return ""
        return super().get_source(fullname)


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


_JAC_PATH_HOOK_INSTALLED = False


def _install_jac_path_hook() -> None:
    """Make Python's path-based import machinery recognize ``.jac``.

    Installs a replacement ``FileFinder`` path hook whose loader list
    includes ``_JacSourceFileLoader`` for ``.jac``, alongside the standard
    Python loaders. The Python suffix list
    (``importlib.machinery.SOURCE_SUFFIXES``) is *deliberately NOT*
    mutated: pytest's assertion-rewriting hook and other tools that
    introspect ``SOURCE_SUFFIXES`` would otherwise pick ``.jac`` up as a
    Python source file and try to AST-parse it.

    Our replacement ``FileFinder`` sees ``.jac`` via its own loader-suffix
    pair and produces specs with ``_JacSourceFileLoader`` — good enough
    for PyInstaller's analyzer and similar path-based tooling. Idempotent.
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

    replaced = False
    for i, hook in enumerate(list(sys.path_hooks)):
        if getattr(hook, "__name__", "") == "path_hook_for_FileFinder":
            sys.path_hooks[i] = new_hook
            replaced = True
            break
    if not replaced:
        sys.path_hooks.insert(0, new_hook)

    sys.path_importer_cache.clear()
    _JAC_PATH_HOOK_INSTALLED = True


def install() -> None:
    """Register the lazy meta-path finder if no Jac importer is already present.

    Does NOT install the path-level ``.jac`` hook. That hook makes ``.jac``
    visible to tools that iterate ``importlib.machinery`` suffixes (pytest's
    assertion rewriter, setuptools, etc.), which would then try to AST-parse
    Jac source as Python and crash. PyInstaller's adapter calls
    ``_install_jac_path_hook()`` directly at hook-load time — the only
    moment when the path-level registration is useful and safe.
    """
    for f in sys.meta_path:
        name = type(f).__name__
        if name in ("JacMetaImporter", "_JacLazyFinder"):
            return
    # Insert at position 0 so the lazy finder runs BEFORE platform-specific
    # meta-path finders like PyInstaller's frozen-app PYZ finder, which
    # would otherwise claim a .jac module via a compiled empty stub.
    sys.meta_path.insert(0, _JacLazyFinder())
