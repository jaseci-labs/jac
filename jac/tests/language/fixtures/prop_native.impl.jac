"""Accessor bodies for Circle.radius declared in prop_native.jac.

Demonstrates that property accessors can be implemented in a sibling
.impl.jac file using dotted-impl syntax, just like regular methods.
Storage is accessed via the explicit backing field `self._radius` —
there is no `field` keyword.
"""
impl Circle.radius.getter -> float {
    return self._radius;
}

impl Circle.radius.setter(value: float) {
    if value < 0.0 {
        raise ValueError("radius must be non-negative");
    }
    self._radius = value;
}

impl Circle.radius.deleter {
    self._radius = 0.0;
}
