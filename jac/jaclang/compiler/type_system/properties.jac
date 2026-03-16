"""Property type utilities for Jac type system.

Handles @property, @cached_property, and custom descriptor protocols.
"""
import from . { types }
import jaclang.jac0core.unitree as uni;

# =============================================================================
# Property detection
# =============================================================================
"""Check if decorator type is the builtin property class."""
def is_property_decorator_type(decorator_type: types.TypeBase) -> bool;

"""Check if decorator type is cached_property from functools."""
def is_cached_property_decorator_type(decorator_type: types.TypeBase) -> bool;

# =============================================================================
# Property creation
# =============================================================================
"""Create a property ClassType from a getter function."""
def create_property(
    fget: types.FunctionType, class_type: (types.ClassType | None) = None
) -> types.ClassType;

"""Clone a property and add a setter."""
def clone_property_with_setter(
    prop: types.ClassType, fset: types.FunctionType
) -> types.ClassType;

"""Clone a property and add a deleter."""
def clone_property_with_deleter(
    prop: types.ClassType, fdel: types.FunctionType
) -> types.ClassType;

# =============================================================================
# Property type checking
# =============================================================================
"""Check if a type is a property class instance."""
def is_property(ty: types.TypeBase) -> bool;
