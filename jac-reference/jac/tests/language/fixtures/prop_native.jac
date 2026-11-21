"""Native property syntax — getter / setter / deleter with impl separation.

Exercises the `has <name>: <type> { getter; setter; deleter; }` form:
  - inline property over explicit backing storage
  - read-only computed property (no backing field)
  - full custom property whose accessor *signatures* live here and whose
    *bodies* live in prop_native.impl.jac, mirroring Jac's def/impl split.

Properties are pure computed accessors: they never allocate backing storage
implicitly. Users declare backing fields explicitly via `has _x: T = value;`
and reference them as `self._x` from accessor bodies.
"""

obj Circle {
    # Backing storage for `color` and `radius` (explicit, just normal fields).
    has _color: str = "black",
        _radius: float = 1.0;

    # 1. Property over explicit backing storage: inline bodies.
    has color: str {
        getter -> str { return self._color; }
        setter(value: str) { self._color = value; }
    }

    # 2. Read-only computed: no backing needed, getter computes from other fields.
    has diameter: float {
        getter { return self._radius * 2.0; }
    }

    # 3. Full custom property — signatures only; bodies in prop_native.impl.jac.
    has radius: float {
        getter -> float;
        setter(value: float);
        deleter;
    }
}

with entry {
    c = Circle();

    # --- writable property over backing: color ---
    assert c.color == "black";
    c.color = "red";
    assert c.color == "red";

    # --- read-only computed: diameter (default _radius is 1.0) ---
    assert c.diameter == 2.0;
    c.radius = 5.0;
    assert c.diameter == 10.0;

    # --- impl-separated setter validation rejects negatives ---
    rejected = False;
    try {
        c.radius = -1.0;
    } except ValueError as e {
        rejected = True;
        assert str(e) == "radius must be non-negative";
    }
    assert rejected;
    assert c.radius == 5.0;  # unchanged after rejected write

    # --- impl-separated deleter resets the backing field ---
    del c.radius;
    assert c.radius == 0.0;

    print("ok");
}
