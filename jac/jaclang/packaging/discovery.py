"""Jac package discovery — pure Python, callable from build-time contexts.

Consumed today by ``jaclang._pyinstaller``; intended for any future bundler
(``jac build --target=binary``, Nuitka adapter, etc.) to reuse.
"""

from __future__ import annotations

import os
from collections.abc import Iterable, Iterator
from dataclasses import dataclass

INIT_JAC = "__init__.jac"
JAC_SUFFIX = ".jac"
JACLANG_DATA_EXTS: tuple[str, ...] = (".jac", ".jir", ".lark", ".pyi")
JACLANG_DATA_BASENAMES: frozenset[str] = frozenset({"manifest.json"})


@dataclass(frozen=True)
class JacSource:
    """A ``.jac`` file belonging to a discovered package."""

    path: str
    module_name: str
    relative_path: str


@dataclass(frozen=True)
class JacPackage:
    """A top-level Jac package — a directory containing ``__init__.jac``."""

    name: str
    root: str

    def iter_sources(self) -> Iterator[JacSource]:
        """Yield every ``.jac`` under ``root``; hidden subdirs skipped."""
        parent = os.path.dirname(self.root)
        for root, dirs, files in os.walk(self.root):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            rel_dir = os.path.relpath(root, parent)
            dotted = rel_dir.replace(os.sep, ".")
            for fname in files:
                if not fname.endswith(JAC_SUFFIX):
                    continue
                stem = fname[: -len(JAC_SUFFIX)]
                yield JacSource(
                    path=os.path.join(root, fname),
                    module_name=dotted if stem == "__init__" else f"{dotted}.{stem}",
                    relative_path=os.path.join(rel_dir, fname),
                )


def find_packages(search_dirs: Iterable[str]) -> list[JacPackage]:
    """Return every immediate-child dir with ``__init__.jac`` under ``search_dirs``.

    Skips hidden / dunder directories. Dedupes across search dirs.
    """
    found: list[JacPackage] = []
    seen: set[str] = set()
    for raw in search_dirs:
        if not raw or not os.path.isdir(raw):
            continue
        search_dir = os.path.abspath(raw)
        try:
            entries = os.listdir(search_dir)
        except OSError:
            continue
        for entry in entries:
            full = os.path.join(search_dir, entry)
            if (
                not os.path.isdir(full)
                or entry.startswith((".", "_"))
                or not os.path.isfile(os.path.join(full, INIT_JAC))
                or full in seen
            ):
                continue
            seen.add(full)
            found.append(JacPackage(name=entry, root=full))
    return found


def iter_jaclang_data_files() -> Iterator[tuple[str, str]]:
    """Yield ``(abs_path, parent_rel_dir)`` for jaclang's non-Python runtime assets.

    Walks the installed jaclang tree directly because editable installs
    frequently omit package-data globs from dist-info metadata.
    """
    import jaclang

    root = os.path.dirname(jaclang.__file__)
    parent = os.path.dirname(root)
    for dirpath, _, files in os.walk(root):
        rel_dir = os.path.relpath(dirpath, parent)
        for fname in files:
            if fname.endswith(JACLANG_DATA_EXTS) or fname in JACLANG_DATA_BASENAMES:
                yield os.path.join(dirpath, fname), rel_dir
