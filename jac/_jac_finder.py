"""Lightweight lazy finder for .jac modules.

Installed by the jac binary's launcher at startup (``import _jac_finder;
_jac_finder.install()`` in launcher.zig BOOT_SRC). Costs ~0ms for non-Jac
Python. On first .jac import, triggers ``import jaclang`` to bootstrap the full
compiler, then delegates to the real JacMetaImporter.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import os
import site
import sys
from collections.abc import Sequence
from types import ModuleType


def _find_project_toml() -> str | None:
    """Walk up from the cwd to the nearest ``jac.toml``; return its path or None.

    Shared by ``add_project_venv_to_path`` and ``apply_dev_source_override`` so
    both anchor on the same project root. Plain Python, never fatal.
    """
    directory = os.getcwd()
    while True:
        candidate = os.path.join(directory, "jac.toml")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(directory)
        if parent == directory:
            return None
        directory = parent


def apply_dev_source_override() -> None:
    """Reroute ``import jaclang`` to an in-repo source tree -- an editable dev loop.

    When the nearest ``jac.toml`` declares::

        [dev]
        jaclang_source = "jac"   # dir CONTAINING jaclang/, relative to jac.toml

    this prepends that directory to the FRONT of ``sys.path`` so ``import
    jaclang`` resolves to the live source instead of the single binary's bundled
    copy -- edits take effect with no rebuild. It runs in ``sitecustomize``
    during site init, BEFORE the launcher's BOOT_SRC does ``import jaclang``, so
    the override wins over the bundled ``site/`` on ``PYTHONPATH``.

    Caches: sets ``JAC_NO_PRECOMPILE=1`` so the shipped, version-keyed
    ``_precompiled`` JIR bundle is skipped. The per-module ``.jir`` cache is
    content-keyed (``compute_module_key`` folds the source sha256), so source
    edits self-invalidate on their own -- no forced full rebuild needed. Exports
    ``JAC_DEV_SOURCE`` as a marker for tooling.

    Plain Python, dev-only, never fatal. A cheap substring guard avoids importing
    ``tomllib`` unless the key is literally present, so non-dev startup pays only
    a small file read.
    """
    try:
        toml = _find_project_toml()
        if toml is None:
            return
        with open(toml, "rb") as handle:
            raw = handle.read()
        # Fast path: skip the tomllib import/parse entirely unless the key exists.
        if b"jaclang_source" not in raw:
            return
        import tomllib

        section = tomllib.loads(raw.decode("utf-8")).get("dev")
        if not isinstance(section, dict):
            return
        src = section.get("jaclang_source")
        if not isinstance(src, str) or not src:
            return
        src_dir = os.path.abspath(os.path.join(os.path.dirname(toml), src))
        # Must contain a `jaclang/` package, else this would shadow nothing
        # useful and risk hiding the real bundled copy.
        if not os.path.isdir(os.path.join(src_dir, "jaclang")):
            return
        if src_dir in sys.path:
            sys.path.remove(src_dir)
        sys.path.insert(0, src_dir)
        os.environ["JAC_DEV_SOURCE"] = src_dir
        os.environ.setdefault("JAC_NO_PRECOMPILE", "1")
    except Exception:
        # Dev convenience only; fall back to the bundled jaclang.
        pass


def add_project_venv_to_path() -> None:
    """Put the current project's ``.jac/venv`` site-packages on ``sys.path``.

    The single-binary model installs a project's deps and plugins into its
    ``.jac/venv`` (``jac install [-e] <pkg>``). This walks up from the cwd to the
    nearest ``jac.toml`` and registers that venv's site-packages so the deps,
    and any ``[jac]`` entry-point plugins, are importable.

    Called from ``sitecustomize`` (so it runs in BOTH the jac CLI and bare
    ``jac -m <tool>`` python-mode, before plugin enumeration) and from
    ``jaclang/__init__`` (library-use fallback). Uses ``site.addsitedir`` rather
    than ``sys.path.insert`` because it also processes ``.pth`` files -- that is
    how an editable install (``jac install -e``) puts the package source on the
    path. Plain Python, no jaclang import, idempotent, never fatal.
    """
    try:
        toml = _find_project_toml()
        if toml is None:
            return
        venv = os.path.join(os.path.dirname(toml), ".jac", "venv")
        if os.name == "nt":
            site_packages = os.path.join(venv, "Lib", "site-packages")
        else:
            site_packages = ""
            lib = os.path.join(venv, "lib")
            if os.path.isdir(lib):
                for entry in sorted(os.listdir(lib)):
                    cand = os.path.join(lib, entry, "site-packages")
                    if entry.startswith("python") and os.path.isdir(cand):
                        site_packages = cand
                        break
        if (
            site_packages
            and os.path.isdir(site_packages)
            and site_packages not in sys.path
        ):
            # addsitedir appends (and processes .pth, which editable installs
            # rely on), but a project's venv must take PRECEDENCE -- its pinned
            # deps have to shadow the binary's global site and any leaked system
            # site-packages. So promote everything addsitedir just added to the
            # front of sys.path, preserving their relative order.
            before = list(sys.path)
            site.addsitedir(site_packages)
            added = [p for p in sys.path if p not in before]
            if added:
                sys.path[:] = added + [p for p in sys.path if p not in added]
    except Exception:
        # Discovery falls back to the binary's own site; never fatal.
        pass


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
