"""Backward-compatible lazy alias for :mod:`jaclang.jac0core.runtime`.

Historically ``import jaclang`` eagerly registered
``jaclang.runtimelib.runtime`` as an alias of ``jaclang.jac0core.runtime`` in
``sys.modules``. That eager registration pulled the (heavy) runtime onto every
``import jaclang`` -- including the ``jac --version`` / ``--help`` / ``purge``
fast paths -- so the runtime now loads lazily (see ``jaclang/__init__.py``).

This shim preserves the legacy import surface without defeating that laziness:
``import jaclang.runtimelib.runtime`` and
``from jaclang.runtimelib.runtime import JacRuntime`` keep working, and the real
runtime is only imported when an attribute is actually accessed.
"""

from __future__ import annotations


def __getattr__(name: str) -> object:
    import jaclang.jac0core.runtime as _runtime_mod

    return getattr(_runtime_mod, name)
