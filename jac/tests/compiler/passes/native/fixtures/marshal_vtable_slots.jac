"""Fixture for #8084: struct slots no `has` names still occupy the layout.

`Plain` has no vtable, so its first field sits in slot 0. `Base`/`Derived`
carry a vtable pointer, which takes slot 0 and pushes `x` to slot 1. `Tagged`
is an OSP archetype, so a type tag follows the vtable pointer and its first
field lands in slot 2. A marshaller that appends only the named fields puts
all three at ctypes offset 0 and reads every later field one word low.

The values are distinct per field so a shifted read is a wrong number rather
than a coincidence.
"""

obj Plain {
    has a: int = 11,
        b: int = 22;
}

obj Base {
    has x: int = 1,
        y: int = 2;
}

obj Derived(Base) {
    has z: int = 3;
}

node Tagged {
    has n: int = 44;
}

def make_plain -> Plain {
    return Plain();
}

def make_base -> Base {
    return Base();
}

def make_derived -> Derived {
    return Derived();
}
