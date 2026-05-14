"""Accessor bodies for Circle.radius declared in prop_native.jac.

Demonstrates that the property's three accessors can be implemented in a
sibling .impl.jac file using dotted-impl syntax, just like regular methods.
`field` inside these bodies refers to the property's auto-generated
backing storage.
"""
impl Circle.radius.get -> float {
    return field;
}

impl Circle.radius.set(value: float) {
    if value < 0.0 {
        raise ValueError("radius must be non-negative");
    }
    field = value;
}

impl Circle.radius.del{
    field = 0.0;
}
