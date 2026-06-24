"""Workstream A1 (issue #6930): `isinstance()` over user archetypes.

Exercises native lowering of `isinstance(x, UserClass)`:
  * exact-type and subclass matching (inheritance-aware via the C3 MRO),
  * tuple-of-user-classes (`isinstance(x, (A, B))`),
  * checker-driven narrowing so field access compiles inside the guard,
  * a base-typed (`Shape`) operand holding heterogeneous subclasses.

All driver functions return `int` so they are callable via ctypes.
"""

obj Shape {
    has sides: int = 0;

    def area -> int {
        return 0;
    }
}

obj Square(Shape) {
    has side: int = 0;

    def area -> int {
        return self.side * self.side;
    }
}

obj Circle(Shape) {
    has radius: int = 0;

    def area -> int {
        return 3 * self.radius * self.radius;
    }
}

# Deeper subclass: must still match `isinstance(x, Square)` and `Shape`.
obj ColoredSquare(Square) {
    has color: int = 0;
}

# Standalone struct (no inheritance -> no vtable). `isinstance` against a
# vtable-bearing class must be a principled `False`, not a garbage read of
# field 0 (which here is the first user field, not a vtable slot).
obj Loose {
    has v: int = 0;
}

def make(kind: int) -> Shape {
    if kind == 1 {
        return Circle(radius=2);
    }
    if kind == 2 {
        return Square(side=3);
    }
    if kind == 3 {
        return ColoredSquare(side=4, color=7);
    }
    return Shape(sides=9);
}

# Branch on isinstance; subclass (ColoredSquare) must satisfy `Square`.
def kind_code(s: Shape) -> int {
    if isinstance(s, Circle) {
        return 1;
    }
    if isinstance(s, Square) {
        return 2;
    }
    return 0;
}

# Narrowing: after `isinstance(s, Square)` the checker narrows `s` to `Square`,
# so `s.side` resolves to a concrete field offset natively.
def square_side(s: Shape) -> int {
    if isinstance(s, Square) {
        return s.side;
    }
    return -1;
}

# Tuple of user classes.
def is_round_or_square(s: Shape) -> bool {
    return isinstance(s, (Circle, Square));
}

def test_kind(kind: int) -> int {
    return kind_code(make(kind));
}

def test_side(kind: int) -> int {
    return square_side(make(kind));
}

def test_round_or_square(kind: int) -> int {
    return 1 if is_round_or_square(make(kind)) else 0;
}

def test_loose_not_square -> int {
    return 1 if isinstance(Loose(v=5), Square) else 0;
}

with entry {
    print(test_kind(1));
}
