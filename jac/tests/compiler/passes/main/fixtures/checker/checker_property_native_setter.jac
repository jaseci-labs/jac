"""Native-property setter type-check coverage.

Using the `has x: T { getter; setter; }` form (which avoids the @<name>.setter
decorator-resolution path entirely), assignment must validate against the
property's declared type. Read-only properties (no `setter` accessor) must
emit E1005 on assignment.
"""

obj Circle {
    has _radius: float = 1.0;

    # writable: declared type is float — assignment must validate against it
    has radius: float {
        getter -> float { return self._radius; }
        setter(value: float) { self._radius = value; }
    }

    # read-only: no setter declared — assignment must emit E1005
    has area: float {
        getter { return self._radius * self._radius * 3.14159; }
    }
}

with entry {
    c = Circle();

    # OK — float to float
    c.radius = 5.0;

    # OK — int to float (widens)
    c.radius = 7;

    # ERROR — str to float
    c.radius = "wrong";  # <-- type-error here

    # ERROR — area has no setter (read-only property)
    c.area = 12.5;       # <-- E1005 read-only property here
}
