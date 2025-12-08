"""Jac Library - User-friendly interface for library mode."""

import sys
from collections.abc import Callable
from contextlib import suppress
from typing import TYPE_CHECKING, cast

from jaclang.runtimelib.runtime import JacClassReferences, JacRuntimeInterface

# Pre-populate __all__ with common exports so "from jaclang.lib import X" works
__all__ = [
    # Class references
    "Node",
    "Edge",
    "Walker",
    "Obj",
    "Root",
    "GenericEdge",
    "OPath",
    "DSFunc",
    # Common runtime methods
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

if TYPE_CHECKING:
    from jaclang.runtimelib.archetype import GenericEdge, Root
    from jaclang.runtimelib.archetype import ObjectSpatialFunction as DSFunc
    from jaclang.runtimelib.archetype import ObjectSpatialPath as OPath
    from jaclang.runtimelib.constructs import Archetype as Obj
    from jaclang.runtimelib.constructs import EdgeArchetype as Edge
    from jaclang.runtimelib.constructs import NodeArchetype as Node
    from jaclang.runtimelib.constructs import WalkerArchetype as Walker
    from jaclang.runtimelib.runtime import JacRuntimeInterface as JacRT

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
    """Lazy attribute access to initialize imports when needed."""
    # Don't initialize lazy imports for special/private attributes
    # This prevents circular imports during module loading
    if name.startswith("_"):
        raise AttributeError(f"module '{__name__}' has no attribute '{name}'")

    # Don't check for circular imports - just proceed normally
    # The circular import protection was preventing legitimate imports
    # Instead, rely on the lazy initialization in _init_lazy_imports()

    from jaclang.runtimelib.runtime import _init_lazy_imports, _lazy_imports_initialized

    # Try to initialize lazy imports (may fail during circular import)
    _init_lazy_imports()

    # Try to get attribute from JacClassReferences first (for Node, Edge, etc.)
    # Call the __getattr__ method directly since it's a staticmethod
    try:
        value = JacClassReferences.__getattr__(name)
        # Cache it in module globals for future access (if fully initialized)
        if _lazy_imports_initialized:
            globals()[name] = value
        return value
    except AttributeError:
        pass

    # Get attribute from JacRuntimeInterface (for methods like root, spawn, etc.)
    # This works even if lazy imports haven't completed yet
    if hasattr(JacRuntimeInterface, name):
        value = getattr(JacRuntimeInterface, name)
        # Cache it in module globals for future access (if fully initialized)
        if _lazy_imports_initialized:
            globals()[name] = value
        return value

    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


# Build __all__ - this will be populated lazily
def __dir__() -> list[str]:
    """Return list of available attributes."""
    from jaclang.runtimelib.runtime import _init_lazy_imports

    _init_lazy_imports()
    return sorted(
        [name for name in dir(JacRuntimeInterface) if not name.startswith("_")]
    )


# Populate the module namespace with lazy references
# This enables "from jaclang.lib import Node" to work
def _populate_namespace() -> None:
    """Populate the module namespace with class and method references."""

    current_module = sys.modules[__name__]

    # Create lazy wrapper that will trigger initialization on first access
    class LazyRef:
        def __init__(self, attr_name: str) -> None:
            self.attr_name = attr_name
            self._resolved: object | None = None

        def _resolve(self) -> object:
            if self._resolved is None:
                # Call __getattr__ directly to avoid recursion
                self._resolved = current_module.__getattr__(self.attr_name)
                # Replace ourselves in the module dict with the actual value
                setattr(current_module, self.attr_name, self._resolved)
            return self._resolved

        def __call__(self, *args: object, **kwargs: object) -> object:
            resolved = cast(Callable[..., object], self._resolve())
            return resolved(*args, **kwargs)

        def __getattr__(self, name: str) -> object:
            return getattr(self._resolve(), name)

        def __mro_entries__(self, bases: tuple[type, ...]) -> tuple[type, ...]:
            # Support for using LazyRef in class inheritance
            # When used as a base class, resolve and return the actual class
            return (cast(type, self._resolve()),)

    # Add lazy references to module __dict__
    # Note: hasattr() triggers __getattr__ which resolves and caches the actual values
    for name in __all__:
        if not hasattr(current_module, name):
            setattr(current_module, name, LazyRef(name))


# Don't populate namespace at import time - it causes circular imports
# The hasattr() check in _populate_namespace triggers __getattr__ which
# tries to import constructs while it's still loading
# Instead, we'll populate on first actual use
with suppress(ImportError):
    _populate_namespace()
