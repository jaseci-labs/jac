"""Native property syntax — get / set / del with impl separation.

Exercises the proposed `has <name>: <type> { get; set; del; }` form:
  - inline auto-property (trivial get + set)
  - read-only computed property (no backing field — `field` never appears)
  - full custom property whose accessor *signatures* live here and whose
    *bodies* live in prop_native.impl.jac, mirroring Jac's def/impl split.

Inside any accessor body, `field` is the contextual keyword for the property's
auto-generated backing storage. Its presence/absence determines whether a
backing slot is allocated.
"""

obj Circle {
    # 1. Inline auto-property: storage synthesized, both accessors trivial.
    has color: str = "black" { get; set; };

    # 2. Read-only computed property: no `field` reference -> no storage.
    has diameter: float {
        get { return self.radius * 2.0; }
    }

    # 3. Full custom property — signatures only; bodies in prop_native.impl.jac.
    has radius: float = 1.0 {
        get -> float;
        set(value: float);
        del;
    }
}

with entry {
    c = Circle();

    # --- inline auto-property: color ---
    assert c.color == "black";
    c.color = "red";
    assert c.color == "red";

    # --- computed read-only: diameter (default radius is 1.0) ---
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
