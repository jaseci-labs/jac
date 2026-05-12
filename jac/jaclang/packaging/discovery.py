"""Jac package discovery — callable from build-time contexts (PyInstaller, etc.)."""

from __future__ import annotations

import os
from collections.abc import Iterable, Iterator

_INIT_JAC = "__init__.jac"
_JAC = ".jac"
_JACLANG_EXTS = (".jac", ".jir", ".lark", ".pyi")
_JACLANG_EXTRA = frozenset({"manifest.json"})


def iter_user_jac_sources(search_dirs: Iterable[str]) -> Iterator[tuple[str, str]]:
    """Yield ``(abs_path, dest_dir)`` for every ``.jac`` under a top-level package.

    A "top-level package" is an immediate child of ``search_dirs`` that contains
    ``__init__.jac``. Hidden / dunder dirs are skipped; dedup by absolute path.
    """
    seen: set[str] = set()
    for raw in search_dirs:
        if not raw or not os.path.isdir(raw):
            continue
        for entry in os.listdir(raw):
            full = os.path.abspath(os.path.join(raw, entry))
            if (
                entry.startswith((".", "_"))
                or not os.path.isdir(full)
                or not os.path.isfile(os.path.join(full, _INIT_JAC))
                or full in seen
            ):
                continue
            seen.add(full)
            parent = os.path.dirname(full)
            for dirpath, dirs, files in os.walk(full):
                dirs[:] = [d for d in dirs if not d.startswith(".")]
                rel = os.path.relpath(dirpath, parent)
                for f in files:
                    if f.endswith(_JAC):
                        yield os.path.join(dirpath, f), rel


def iter_jaclang_data_files() -> Iterator[tuple[str, str]]:
    """Yield ``(abs_path, dest_dir)`` for jaclang's non-Python runtime assets."""
    import jaclang

    root = os.path.dirname(jaclang.__file__)
    parent = os.path.dirname(root)
    for dirpath, _, files in os.walk(root):
        rel = os.path.relpath(dirpath, parent)
        for f in files:
            if f.endswith(_JACLANG_EXTS) or f in _JACLANG_EXTRA:
                yield os.path.join(dirpath, f), rel
