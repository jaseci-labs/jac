"""Jac Library - User-friendly interface for library mode."""

from jaclang.runtimelib.machine import JacMachineInterface

# Automatically expose all public attributes from JacMachineInterface
# This includes archetype classes (Obj, Node, Edge, Walker, Root, OPath) and all methods
_jac_interface_attrs = {
    name: getattr(JacMachineInterface, name)
    for name in dir(JacMachineInterface)
    if not name.startswith("_")
}

# Add to module globals
globals().update(_jac_interface_attrs)

# Build __all__ with all JacMachineInterface exports
__all__ = sorted(_jac_interface_attrs.keys())
