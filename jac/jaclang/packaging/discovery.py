"""Discover Jac packages on disk.

First-class jaclang capability for "what Jac packages live under these
directories, and what ``.jac`` files belong to them?" Used by:

* the PyInstaller adapter in ``jaclang._pyinstaller``, to decide which
  ``.jac`` files to copy into a frozen app bundle;
* future ``jac build --target=binary`` and any other bundler that needs
  to enumerate Jac sources before compilation.

This module is deliberately **pure Python and dependency-free** so it can
be imported from build-time contexts (PyInstaller hooks, setuptools
plugins, etc.) without bootstrapping the full jaclang runtime.
"""

from __future__ import annotations

import os
from collections.abc import Iterable, Iterator
from dataclasses import dataclass

INIT_JAC = "__init__.jac"
JAC_SUFFIX = ".jac"

# Non-Python runtime assets shipped inside the jaclang package that bundlers
# must copy verbatim: Jac source, precompiled .jir caches, Lark grammars,
# type stubs, the precompiled manifest, etc.
JACLANG_DATA_EXTS: tuple[str, ...] = (".jac", ".jir", ".lark", ".pyi")
JACLANG_DATA_BASENAMES: frozenset[str] = frozenset({"manifest.json"})


@dataclass(frozen=True)
class JacSource:
    """A single ``.jac`` file belonging to a discovered package."""

    path: str
    """Absolute path to the file on disk."""

    module_name: str
    """Full dotted module name (e.g. ``myapp.core.greeter``)."""

    relative_path: str
    """Path relative to the package's *parent* directory
    (e.g. ``myapp/core/greeter.jac``). Preserving this layout is what lets
    bundlers place the file where ``JacMetaImporter`` will find it on
    ``sys.path`` at runtime."""


@dataclass(frozen=True)
class JacPackage:
    """A top-level Jac package discovered on disk."""

    name: str
    """The package's top-level name (e.g. ``myapp``)."""

    root: str
    """Absolute path to the package directory — the one containing
    ``__init__.jac``."""

    def iter_sources(self) -> Iterator[JacSource]:
        """Yield every ``.jac`` file under this package, in ``os.walk`` order.

        Hidden directories (``.cache``, ``.jac``, etc.) are skipped.
        Files in non-hidden subdirectories are yielded regardless of whether
        those subdirectories themselves contain an ``__init__.jac``.
        """
        parent = os.path.dirname(self.root)
        for root, dirs, files in os.walk(self.root):
            dirs[:] = [d for d in dirs if not d.startswith(".")]

            rel_dir = os.path.relpath(root, parent)
            dotted_prefix = rel_dir.replace(os.sep, ".")

            for fname in files:
                if not fname.endswith(JAC_SUFFIX):
                    continue
                stem = fname[: -len(JAC_SUFFIX)]
                module_suffix = "" if stem == "__init__" else "." + stem
                yield JacSource(
                    path=os.path.join(root, fname),
                    module_name=dotted_prefix + module_suffix,
                    relative_path=os.path.join(rel_dir, fname),
                )


def find_packages(search_dirs: Iterable[str]) -> list[JacPackage]:
    """Return every top-level Jac package reachable under ``search_dirs``.

    A "top-level Jac package" is an immediate child directory of one of the
    given search dirs that contains an ``__init__.jac`` file. The same
    absolute directory is never returned twice even if it is reachable via
    multiple search dirs. Hidden and dunder-prefixed directories are
    skipped.
    """
    found: list[JacPackage] = []
    seen: set[str] = set()

    for raw_dir in search_dirs:
        if not raw_dir or not os.path.isdir(raw_dir):
            continue
        search_dir = os.path.abspath(raw_dir)

        try:
            entries = os.listdir(search_dir)
        except OSError:
            continue

        for entry in entries:
            full = os.path.join(search_dir, entry)
            if not os.path.isdir(full):
                continue
            if entry.startswith(".") or entry.startswith("_"):
                continue
            if not os.path.isfile(os.path.join(full, INIT_JAC)):
                continue
            if full in seen:
                continue
            seen.add(full)
            found.append(JacPackage(name=entry, root=full))

    return found


def iter_jaclang_data_files() -> Iterator[tuple[str, str]]:
    """Yield ``(abs_path, parent_rel_dir)`` pairs for jaclang's runtime assets.

    Returns every non-Python file inside the installed jaclang package that
    bundlers must copy verbatim — ``.jac`` sources, ``.jir`` precompiled
    caches, ``.lark`` grammars, ``.pyi`` stubs, the precompiled manifest,
    etc. ``parent_rel_dir`` is the file's directory relative to jaclang's
    *parent*, which is exactly the ``dest_dir`` shape PyInstaller and
    similar bundlers expect for data-file tuples.

    Implemented via direct os.walk rather than
    ``importlib.resources`` / ``collect_data_files`` because editable
    installs frequently fail to expose the full package-data globs in
    dist-info metadata, leaving discovery tools with an incomplete view.
    """
    import jaclang  # local import — this function must remain callable
    # from build-time contexts (PyInstaller hooks) before jaclang's full
    # runtime has finished initializing.

    root = os.path.dirname(jaclang.__file__)
    parent = os.path.dirname(root)

    for dirpath, _, files in os.walk(root):
        rel_dir = os.path.relpath(dirpath, parent)
        for fname in files:
            if fname.endswith(JACLANG_DATA_EXTS) or fname in JACLANG_DATA_BASENAMES:
                yield os.path.join(dirpath, fname), rel_dir
