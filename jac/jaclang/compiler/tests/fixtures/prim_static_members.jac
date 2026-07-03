"""Static-method calls + class-attribute reads on user classes (issue #6951).

The native (na) pathway gains `ClassName.method(args)` on a `static def` and
`ClassName.attr` on a `static has`, both already supported on the sv (Python)
pathway. This fixture pins the two congruent: a static method (incl. one that
reads a class attribute from its own body and one used as a factory returning an
instance), class-attribute reads of int and str, and inheritance of statics
through the MRO. It is the capability that unblocks a CPython-congruent bundled
`datetime` (`datetime.now(...)` classmethod + `timezone.utc` class attribute).
ES/JS opts out.
"""

obj Color {
    static has count: int = 3,
        label: str = "rgb";

    static def shade(level: int) -> int {
        return level * 10;
    }

    """A static method reading a class attribute from its own body."""
    static def combine(a: int, b: int) -> int {
        return a + b + Color.count;
    }
}


obj Base {
    static has tag: int = 7;

    static def origin() -> int {
        return 100;
    }
}


obj Derived(Base) {}


"""Factory pattern: a static method returning a fresh instance (datetime.now
shape), whose instance method is then called."""
obj Point {
    has x: int = 0,
        y: int = 0;

    static def at(x: int, y: int) -> Point {
        return Point(x=x, y=y);
    }

    def sum() -> int {
        return self.x + self.y;
    }
}


def static_members_py() -> dict {
    p = Point.at(3, 4);
    return {
        "shade": Color.shade(5),
        "combine": Color.combine(1, 2),
        "count": Color.count,
        "label": Color.label,
        "derived_tag": Derived.tag,
        "derived_origin": Derived.origin(),
        "factory_sum": p.sum(),

    };
}


cl def static_members_cl() -> dict {
    return {};
}


na {
    def static_members_na() -> dict[str, any] {
        p: Point = Point.at(3, 4);
        return {
            "shade": Color.shade(5),
            "combine": Color.combine(1, 2),
            "count": Color.count,
            "label": Color.label,
            "derived_tag": Derived.tag,
            "derived_origin": Derived.origin(),
            "factory_sum": p.sum(),

        };
    }
}
