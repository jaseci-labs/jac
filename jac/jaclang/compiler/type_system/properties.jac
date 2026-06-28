import from . { types }
import jaclang.jac0core.unitree as uni;

def is_property_decorator_type(decorator_type: types.TypeBase) -> bool;

def is_cached_property_decorator_type(decorator_type: types.TypeBase) -> bool;

def create_property(
    fget: types.FunctionType, class_type: (types.ClassType | None) = None
) -> types.ClassType;

def clone_property_with_setter(
    prop: types.ClassType, fset: types.FunctionType
) -> types.ClassType;

def clone_property_with_deleter(
    prop: types.ClassType, fdel: types.FunctionType
) -> types.ClassType;

def is_property(ty: types.TypeBase) -> bool;
