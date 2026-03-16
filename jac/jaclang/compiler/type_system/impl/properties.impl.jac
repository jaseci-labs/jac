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
    shared = decorator_type.shared;
    if shared is None {
        return False;
    }
    if shared.class_name == "cached_property" and shared.is_from_stdlib_stub {
        return True;
    }
    return False;
}

# =============================================================================
# Property creation
# =============================================================================
"""Create a property ClassType from a getter function."""
impl create_property(
    fget: types.FunctionType, class_type: (types.ClassType | None) = None
) -> types.ClassType {
    private = types.ClassType.ClassDetailsPrivate();
    private.is_property_class = True;
    private.fget_info = fget;

    shared: types.ClassType.ClassDetailsShared;
    if class_type and class_type.shared {
        shared = class_type.shared;
    } else {
        return types.ClassType(private=private, flags=types.TypeFlags.Instance);
    }

    return types.ClassType(
        shared=shared, private=private, flags=types.TypeFlags.Instance
    );
}

"""Clone a property and add a setter."""
impl clone_property_with_setter(
    prop: types.ClassType, fset: types.FunctionType
) -> types.ClassType {
    private = types.ClassType.ClassDetailsPrivate();
    private.is_property_class = True;
    private.fset_info = fset;

    priv = prop.private;
    if priv {
        private.fget_info = priv.fget_info;
        private.fdel_info = priv.fdel_info;
    }

    return types.ClassType(shared=prop.shared, private=private, flags=prop.flags);
}

"""Clone a property and add a deleter."""
impl clone_property_with_deleter(
    prop: types.ClassType, fdel: types.FunctionType
) -> types.ClassType {
    private = types.ClassType.ClassDetailsPrivate();
    private.is_property_class = True;
    private.fdel_info = fdel;

    priv = prop.private;
    if priv {
        private.fget_info = priv.fget_info;
        private.fset_info = priv.fset_info;
    }

    return types.ClassType(shared=prop.shared, private=private, flags=prop.flags);
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
