"""Test CFG-based narrowing for dotted attribute expressions (obj.field)."""

obj Car {
    has speed: int | None;
}

def increment(x: int) -> int {
    return x + 1;
}

# Narrowing via assignment inside if-body + return after if
def test_assign_then_return -> int {
    c = Car(1);
    if c.speed is None {
        c.speed = 0;
    }
    return c.speed;
}

# Narrowing via assignment used inside the same if-body
def test_assign_then_use_in_body -> int {
    c = Car(1);
    if c.speed is None {
        c.speed = 0;
        increment(c.speed);
    }
    return c.speed;
}

# False-branch narrowing (is not None guard)
def test_false_branch -> int {
    c = Car(1);
    if c.speed is not None {
        return c.speed;
    }
    return 0;
}
