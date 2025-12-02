"""Jac Library - User-friendly interface for library mode."""

from jaclang.runtimelib.runtime import JacRuntimeInterface

# Automatically expose all public attributes from JacRuntimeInterface
# This includes archetype classes (Obj, Node, Edge, Walker, Root, OPath) and all methods
_jac_interface_attrs = {
    name: getattr(JacRuntimeInterface, name)
    for name in dir(JacRuntimeInterface)
    if not name.startswith("_")
}

# Add to module globals
globals().update(_jac_interface_attrs)

# Build __all__ with all JacRuntimeInterface exports
__all__ = sorted(_jac_interface_attrs.keys())
