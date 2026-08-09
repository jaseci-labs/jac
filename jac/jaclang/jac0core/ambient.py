"""Jac's ambient type vocabulary, sourced from ``runtimelib/prelude.jac``.

The prelude is a real Jac module whose ``import from`` groups declare the
names every Jac module may use without importing (the checker merges them
into builtins scope; W1103 warns on redundant explicit imports). This module
is the runtime half of that contract: it parses the same declaration and
binds the names into module namespaces at exec time, so the vocabulary holds
on every bytecode tier -- including jac0-compiled bootstrap modules, which
the full compiler's per-reference auto-import never covers.

Like ``sealed.py`` / ``ext_registry.py``, this file is plain Python with no
jaclang dependencies: it must be importable before any ``.jac`` machinery.
"""

from __future__ import annotations

import importlib
import os
import re

PRELUDE_PATH = os.path.join(
    os.path.dirname(__file__), "..", "runtimelib", "prelude.jac"
)

_IMPORT_RE = re.compile(r"import\s+from\s+([\w.]+)\s*\{([^}]*)\}", re.DOTALL)

_groups: dict[str, list[str]] | None = None
_objects: dict[str, object] | None = None


def ambient_imports_by_module() -> dict[str, list[str]]:
    """Names the prelude declares, grouped by source module (parsed once)."""
    global _groups
    if _groups is None:
        groups: dict[str, list[str]] = {}
        try:
            with open(PRELUDE_PATH, encoding="utf-8") as f:
                text = f.read()
        except OSError:
            _groups = {}
            return _groups
        for match in _IMPORT_RE.finditer(text):
            module, body = match.group(1), match.group(2)
            names = [n.strip() for n in body.split(",") if n.strip()]
            if names:
                groups.setdefault(module, []).extend(names)
        _groups = groups
    return _groups


def ambient_objects() -> dict[str, object]:
    """The prelude's names bound to their py-backend runtime objects."""
    global _objects
    if _objects is None:
        objects: dict[str, object] = {}
        for module_name, names in ambient_imports_by_module().items():
            try:
                module = importlib.import_module(module_name)
            except ImportError:
                continue
            for name in names:
                obj = getattr(module, name, None)
                if obj is not None:
                    objects[name] = obj
        _objects = objects
    return _objects


def inject(namespace: dict) -> None:
    """Bind the ambient vocabulary into a module namespace pre-exec.

    ``setdefault`` so the module's own imports and definitions always win.
    """
    for name, obj in ambient_objects().items():
        namespace.setdefault(name, obj)
