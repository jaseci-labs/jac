"""Implementation of property type utilities."""

# =============================================================================
# Property detection
# =============================================================================
"""Check if a decorator type is the builtin property class."""
impl is_property_decorator_type(decorator_type: types.TypeBase) -> bool {
    if not isinstance(decorator_type, types.ClassType) {
        return False;
    }
    return decorator_type.is_builtin("property");
}

"""Check if a decorator type is cached_property from functools."""
impl is_cached_property_decorator_type(decorator_type: types.TypeBase) -> bool {
    if not isinstance(decorator_type, types.ClassType) {
        return False;
    }
    return (
        decorator_type.shared.class_name == "cached_property"
        and decorator_type.shared.is_from_stdlib_stub
    );
}

# =============================================================================
# Property creation
# =============================================================================
"""Create a property ClassType from a getter function."""
impl create_property(
    fget: types.FunctionType, class_type: (types.ClassType | None) = None
) -> types.ClassType {
    new_private = types.ClassType.ClassDetailsPrivate();
    new_private.is_property_class = True;
    new_private.fget_info = fget;

    if class_type is None {
        # Detached property — no enclosing class context available.
        return types.ClassType(private=new_private, flags=types.TypeFlags.Instance);
    }
    return types.ClassType(
        _shared=class_type.shared, private=new_private, flags=types.TypeFlags.Instance
    );
}

"""Clone a property and add a setter."""
impl clone_property_with_setter(
    prop: types.ClassType, fset: types.FunctionType
) -> types.ClassType {
    new_private = types.ClassType.ClassDetailsPrivate();
    new_private.is_property_class = True;
    new_private.fset_info = fset;
    new_private.fget_info = prop.private.fget_info;
    new_private.fdel_info = prop.private.fdel_info;

    return types.ClassType(_shared=prop._shared, private=new_private, flags=prop.flags);
}

"""Clone a property and add a deleter."""
impl clone_property_with_deleter(
    prop: types.ClassType, fdel: types.FunctionType
) -> types.ClassType {
    new_private = types.ClassType.ClassDetailsPrivate();
    new_private.is_property_class = True;
    new_private.fdel_info = fdel;
    new_private.fget_info = prop.private.fget_info;
    new_private.fset_info = prop.private.fset_info;

    return types.ClassType(_shared=prop._shared, private=new_private, flags=prop.flags);
}

# =============================================================================
# Property type checking
# =============================================================================
"""Check if a type is a property class instance."""
impl is_property(ty: types.TypeBase) -> bool {
    if not isinstance(ty, types.ClassType) {
        return False;
    }
    if not ty.is_instance() {
        return False;
    }
    return ty.is_property_class();
}
