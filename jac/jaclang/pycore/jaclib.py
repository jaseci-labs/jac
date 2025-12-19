"""Jac library-mode surface area for Python codegen.

This module exists so the Jac compiler can import Jac "library mode" helpers
without importing `jaclang.lib` during bootstrap (which may require compiling
Jac code via the meta-importer).

It mirrors the behavior of `jaclang/lib.jac` and intentionally keeps the API
names stable because the Jac -> Python code generator emits imports for these.
"""

from __future__ import annotations

import sys
from collections.abc import Callable
from typing import TYPE_CHECKING, cast

from jaclang.pycore.runtime import JacClassReferences, JacRuntimeInterface

__all__ = [
    "Node",
    "Edge",
    "Walker",
    "Obj",
    "Root",
    "GenericEdge",
    "OPath",
    "DSFunc",
    "root",
    "spawn",
    "visit",
    "disengage",
    "connect",
    "disconnect",
    "create_j_context",
    "get_context",
    "reset_machine",
]


if TYPE_CHECKING:  # pragma: no cover
    from jaclang.pycore.runtime import JacRuntimeInterface as JacRT
    from jaclang.runtimelib.archetype import GenericEdge, Root
    from jaclang.runtimelib.archetype import ObjectSpatialFunction as DSFunc
    from jaclang.runtimelib.archetype import ObjectSpatialPath as OPath
    from jaclang.runtimelib.constructs import Archetype as Obj
    from jaclang.runtimelib.constructs import EdgeArchetype as Edge
    from jaclang.runtimelib.constructs import NodeArchetype as Node
    from jaclang.runtimelib.constructs import WalkerArchetype as Walker

    connect: Callable[..., object] = JacRT.connect
    create_j_context: Callable[..., object] = JacRT.create_j_context
    disconnect: Callable[..., object] = JacRT.disconnect
    disengage: Callable[..., object] = JacRT.disengage
    get_context: Callable[..., object] = JacRT.get_context
    reset_machine: Callable[..., object] = JacRT.reset_machine
    root: Callable[..., object] = JacRT.root
    spawn: Callable[..., object] = JacRT.spawn
    visit: Callable[..., object] = JacRT.visit


def __getattr__(name: str) -> object:
    if name.startswith("_"):
        raise AttributeError(f"module '{__name__}' has no attribute '{name}'")

    from jaclang.pycore.runtime import _init_lazy_imports, _lazy_imports_initialized

    _init_lazy_imports()
    try:
        value = JacClassReferences.__getattr__(name)
        if _lazy_imports_initialized:
            globals()[name] = value
        return value
    except AttributeError:
        pass

    if hasattr(JacRuntimeInterface, name):
        value = getattr(JacRuntimeInterface, name)
        if _lazy_imports_initialized:
            globals()[name] = value
        return value

    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def __dir__() -> list[str]:
    from jaclang.pycore.runtime import _init_lazy_imports

    _init_lazy_imports()
    return sorted(
        [name for name in dir(JacRuntimeInterface) if not name.startswith("_")]
    )


def _populate_namespace() -> None:
    current_module = sys.modules[__name__]

    class LazyRef:
        def __init__(self, attr_name: str) -> None:
            self.attr_name = attr_name
            self._resolved: object | None = None

        def _resolve(self) -> object:
            if self._resolved is None:
                self._resolved = current_module.__getattr__(self.attr_name)
                setattr(current_module, self.attr_name, self._resolved)
            return self._resolved

        def __call__(self, *args: object, **kwargs: object) -> object:
            resolved = cast(Callable[..., object], self._resolve())
            return resolved(*args, **kwargs)

        def __getattr__(self, name: str) -> object:
            return getattr(self._resolve(), name)

        def __mro_entries__(self, bases: tuple[type, ...]) -> tuple[type, ...]:
            return (cast(type, self._resolve()),)

    for name in __all__:
        if not hasattr(current_module, name):
            setattr(current_module, name, LazyRef(name))


_populate_namespace()
