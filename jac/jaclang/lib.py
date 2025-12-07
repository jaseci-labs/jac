"""Jac Library - User-friendly interface for library mode."""

import sys
from jaclang.runtimelib.runtime import JacRuntimeInterface, JacClassReferences


def __getattr__(name: str):
    """Lazy attribute access to initialize imports when needed."""
    # Don't initialize lazy imports for special/private attributes
    # This prevents circular imports during module loading
    if name.startswith('_'):
        raise AttributeError(f"module '{__name__}' has no attribute '{name}'")

    # Check if we're in the middle of loading runtimelib modules
    # If so, return a forward reference to avoid circular dependency
    runtimelib_modules = [
        'jaclang.runtimelib.constructs',
        'jaclang.runtimelib.archetype',
        'jaclang.runtimelib.memory',
        'jaclang.runtimelib.mtp',
    ]

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
def __dir__():
    """Return list of available attributes."""
    from jaclang.runtimelib.runtime import _init_lazy_imports

    _init_lazy_imports()
    return sorted([name for name in dir(JacRuntimeInterface) if not name.startswith("_")])


# Pre-populate __all__ with common exports so "from jaclang.lib import X" works
__all__ = [
    # Class references
    "Node", "Edge", "Walker", "Obj", "Root", "GenericEdge", "OPath", "DSFunc",
    # Common runtime methods
    "root", "spawn", "visit", "disengage", "connect", "disconnect",
    "create_j_context", "get_context", "reset_machine",
]


# Populate the module namespace with lazy references
# This enables "from jaclang.lib import Node" to work
def _populate_namespace():
    """Populate the module namespace with class and method references."""
    import sys

    current_module = sys.modules[__name__]

    # Create lazy wrapper that will trigger initialization on first access
    class LazyRef:
        def __init__(self, attr_name):
            self.attr_name = attr_name
            self._resolved = None

        def _resolve(self):
            if self._resolved is None:
                # Call __getattr__ directly to avoid recursion
                self._resolved = current_module.__getattr__(self.attr_name)
                # Replace ourselves in the module dict with the actual value
                setattr(current_module, self.attr_name, self._resolved)
            return self._resolved

        def __call__(self, *args, **kwargs):
            return self._resolve()(*args, **kwargs)

        def __getattr__(self, name):
            return getattr(self._resolve(), name)

        def __mro_entries__(self, bases):
            # Support for using LazyRef in class inheritance
            # When used as a base class, resolve and return the actual class
            return (self._resolve(),)

    # Add lazy references to module __dict__
    for name in __all__:
        if not hasattr(current_module, name):
            setattr(current_module, name, LazyRef(name))


# Don't populate namespace at import time - it causes circular imports
# The hasattr() check in _populate_namespace triggers __getattr__ which
# tries to import constructs while it's still loading
# Instead, we'll populate on first actual use
try:
    _populate_namespace()
except ImportError:
    # Circular import detected - skip for now
    # Namespace will work via __getattr__ fallback
    pass
