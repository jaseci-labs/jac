"""Lightweight lazy finder for .jac modules.

Installed by the jac binary's launcher at startup (``import _jac_finder;
_jac_finder.install()`` in launcher/launcher.jac BOOT_SRC). Costs ~0ms for non-Jac
Python. On first .jac import, triggers ``import jaclang`` to bootstrap the full
compiler, then delegates to the real JacMetaImporter.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import json
import os
import site
import sys
from collections.abc import Sequence
from types import ModuleType

HANDOFF_ENV = "JAC_HANDOFF"


def handoff() -> dict[str, object]:
    """The handoff record this process inherited.

    Deliberate MIRROR of ``jaclang.jac0core.handoff``: this module runs during
    ``sitecustomize``/launcher boot, BEFORE the compiler that will run is chosen
    and importable, and a rerouted process loads it from the kit, so code
    inside ``jaclang`` must never import it from here. Keep the record format
    in lockstep with the canonical module.
    """
    raw = os.environ.get(HANDOFF_ENV, "")
    if not raw:
        return {}
    try:
        record = json.loads(raw)
    except ValueError:
        return {}
    return record if isinstance(record, dict) else {}


def update_handoff(**fields: object) -> None:
    """Mirror of ``jaclang.jac0core.handoff.update_handoff`` (see ``handoff``)."""
    record = handoff()
    for key, value in fields.items():
        if value is None:
            record.pop(key, None)
        else:
            record[key] = value
    if record:
        os.environ[HANDOFF_ENV] = json.dumps(record, sort_keys=True)
    else:
        os.environ.pop(HANDOFF_ENV, None)


def _find_project_toml() -> str | None:
    """Walk up from the cwd to the nearest ``jac.toml``; return its path or None.

    Deliberate plain-Python MIRROR of the single canonical resolver
    ``jaclang.compiler.frontend.helpers.find_project_root``. It cannot import that one
    because this module runs during ``sitecustomize``/launcher boot, BEFORE
    ``import jaclang`` is possible -- it is what sets jaclang up. Keep the walk
    semantics (nearest jac.toml, cwd-anchored at boot) in lockstep with the
    canonical function. Shared by ``add_project_venv_to_path`` and
    ``apply_dev_source_override`` so both anchor on the same project root. Plain
    Python, never fatal.
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


def _baked_source_dir() -> str | None:
    """Return the compiler dir baked into a linked dev binary, or ``None``.

    ``zig build -Ddev`` / ``-Djaclang-dir=PATH`` ships a payload WITHOUT a
    bundled ``jaclang`` and writes the absolute compiler path into a
    ``jac_linked_source`` file beside this module (see ``jaclang.dist.payload``
    ``mkPayload``). Reading it here makes such a binary reroute to live source
    from ANY directory, with no ``[dev]`` ``jac.toml`` stanza in scope. The file
    is one line of plain text; absent on a normal (self-contained) binary.
    """
    marker = os.path.join(os.path.dirname(__file__), "jac_linked_source")
    try:
        with open(marker, encoding="utf-8") as handle:
            return handle.read().strip() or None
    except OSError:
        return None


def _dev_table() -> tuple[str | None, bool]:
    """``[dev] jaclang_source`` (absolute) and ``[dev] exact`` from the nearest
    ``jac.toml``.

    The stanza is read from the NEAREST ``jac.toml`` -- the same project root
    every other config setting resolves against (see ``_find_project_toml``), so
    a directory that wants the loop must carry its own ``[dev]`` stanza rather
    than inherit one from an enclosing project. A cheap substring guard avoids
    importing ``tomllib`` unless a ``[dev]`` table is literally present, so
    non-dev startup pays only a small file read.
    """
    toml = _find_project_toml()
    if toml is None:
        return (None, False)
    with open(toml, "rb") as handle:
        raw = handle.read()
    if b"[dev]" not in raw:
        return (None, False)
    import tomllib

    section = tomllib.loads(raw.decode("utf-8")).get("dev")
    if not isinstance(section, dict):
        return (None, False)
    exact = section.get("exact") is True
    src = section.get("jaclang_source")
    if not isinstance(src, str) or not src:
        return (None, exact)
    return (os.path.abspath(os.path.join(os.path.dirname(toml), src)), exact)


def _is_bare_checkout(src_dir: str) -> bool:
    """Whether ``src_dir`` holds the compiler's source but not its typeshed stubs.

    A git checkout carries ``jaclang/`` but not ``jaclang/vendor/typeshed/stdlib``:
    the stdlib stubs are gitignored and materialized by ``zig build
    fetch-typeshed`` (part of a plain ``zig build``). The type checker loads
    ``builtins.pyi`` / ``typing.pyi`` from that directory for every compile, so
    rerouting into a tree that never ran the build step breaks the first
    compile with ``Stub file not found``. That tree is a fresh clone met with a
    released binary -- how a quickstart reader arrives at a repo whose
    ``jac.toml`` ships a ``[dev]`` stanza for its contributors -- and the loop
    must refuse it rather than crash. A directory with no ``jaclang/`` at all is
    not "bare"; the caller already skips those silently.
    """
    if not os.path.isdir(os.path.join(src_dir, "jaclang")):
        return False
    return not os.path.isfile(
        os.path.join(
            src_dir, "jaclang", "vendor", "typeshed", "stdlib", "builtins.pyi"
        )
    )


def apply_dev_source_override() -> None:
    """Reroute ``import jaclang`` to an in-repo source tree -- an editable dev loop.

    Which compiler a process runs is decided once per process tree:

    1. A process that inherits a handoff record (``handoff()``) runs its
       parent's compiler, whatever its cwd: the ``compiler_source`` the parent
       recorded, or the bundled compiler when that is empty. A child spawned
       into another directory (a native build into a temp dir, a desktop build
       compiling its host) therefore stays on its parent's compiler, and a
       tree started outside any ``[dev]`` project stays on the bundled one even
       when its children run inside the repo.
    2. A top-level process reads ``[dev] jaclang_source`` from the nearest
       ``jac.toml``::

           [dev]
           jaclang_source = "jac"   # dir CONTAINING jaclang/, relative to jac.toml
           exact = true             # optional: never reuse an earlier compiler's products

       Inside a repo that declares its own compiler source, THAT source is the
       developer's intent -- even when the running binary is a linked dev
       binary baked to a different checkout.
    3. Otherwise a ``jac_linked_source`` marker baked into a linked dev binary
       (``zig build -Ddev`` / ``-Djaclang-dir``; see ``_baked_source_dir``) --
       the cwd-independent "linked compiler" mode, where the binary ships no
       bundled ``jaclang``. A baked link always applies: it is that binary's
       only compiler.

    The chosen directory is prepended to the FRONT of ``sys.path`` so
    ``import jaclang`` resolves to the live source instead of the binary's
    bundled copy. This runs in ``sitecustomize`` during site init, BEFORE the
    launcher's BOOT_SRC does ``import jaclang``.

    A ``jac.toml`` source is applied only when its tree is materialized (see
    ``_is_bare_checkout``); a bare clone is refused with a note and the
    bundled compiler serves. An inherited record is not re-judged: the top of
    the tree already chose.

    The decision is recorded in the handoff (``compiler_source``, empty for the
    bundled compiler, and ``exact``). ``compiler_source`` is also the scope of
    the ``_precompiled`` bundle lookup: the shipped, version-keyed bundle
    inside the binary's payload belongs to another jaclang and must never
    serve a source run, while a bundle INSIDE this tree was built from it and
    may (``jir.bundle_dir_allowed``).

    Plain Python, dev-only, never fatal.
    """
    try:
        inherited = handoff()
        if "compiler_source" in inherited:
            # The top of this process tree already chose; its children run it.
            src_dir = str(inherited.get("compiler_source") or "") or None
            exact = bool(inherited.get("exact"))
        else:
            (src_dir, exact) = _dev_table()
            if src_dir is not None and _is_bare_checkout(src_dir):
                sys.stderr.write(
                    f"jac: ignoring the dev compiler source {src_dir}: the tree "
                    "has no typeshed stdlib stubs (run `zig build fetch-typeshed` "
                    "in that checkout to use its compiler); the bundled compiler "
                    "serves this run.\n"
                )
                src_dir = None
        src_dir = src_dir or _baked_source_dir()
        if src_dir is not None and not os.path.isdir(os.path.join(src_dir, "jaclang")):
            src_dir = None
        if src_dir is not None:
            if src_dir in sys.path:
                sys.path.remove(src_dir)
            sys.path.insert(0, src_dir)
        update_handoff(compiler_source=src_dir or "", exact=exact or None)
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
        # Jac packages (`jac install`) are mounted under .jac/packages as
        # <org>/<name>; the directory is a search root ahead of the venv so a
        # package's .py modules import as org.name.* like its .jac ones.
        mounts = os.path.join(os.path.dirname(toml), ".jac", "packages")
        if os.path.isdir(mounts) and mounts not in sys.path:
            sys.path.insert(0, mounts)
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
        # Prefer the linked dev source when set (the handoff's compiler_source,
        # recorded by apply_dev_source_override): a `-Ddev` binary ships no bundled jaclang/
        # beside this module, so the registry lives only in the linked tree. Fall
        # back through the baked marker directly (resilient even if
        # apply_dev_source_override never ran), then the bundled copy beside this
        # module for a normal self-contained binary.
        base = (
            str(handoff().get("compiler_source") or "")
            or _baked_source_dir()
            or os.path.dirname(__file__)
        )
        path = os.path.join(base, "jaclang", "jac0core", "ext_registry.py")
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
        reg = _ext_registry()
        for init_name in reg.INIT_FILES:
            if os.path.isfile(os.path.join(directory, init_name)):
                return True
        # An implicit namespace package (no __init__) is Jac's when a .jac source
        # lives anywhere in its subtree -- including an intermediate directory
        # that holds only subpackages (issue #7211). Without claiming it, Python
        # would own it as a plain namespace package.
        return reg.is_jac_namespace_package(directory)

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
