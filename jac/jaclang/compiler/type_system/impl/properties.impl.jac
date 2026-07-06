impl is_property_decorator_type(decorator_type: types.TypeBase) -> bool {
    if not isinstance(decorator_type, types.ClassType) {
        return False;
    }
    return decorator_type.is_builtin("property");
}

impl is_cached_property_decorator_type(decorator_type: types.TypeBase) -> bool {
    if not isinstance(decorator_type, types.ClassType) {
        return False;
    }
    return (
        decorator_type.shared.class_name == "cached_property"
        and decorator_type.shared.is_from_stdlib_stub
    );
}
