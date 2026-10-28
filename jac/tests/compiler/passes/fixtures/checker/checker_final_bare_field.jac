import from typing { Final }

glob LIMIT: Final;  # <-- Error

obj P {
    has x: Final;  # <-- Error
}

obj Q {
    has y: Final = 5;
}

def scale(n: int) -> int {
    factor: Final;  # <-- Error
    rate: Final = 2;
    return n * rate;
}

with entry {
    p = P(x="not an int");
    print(p.x, Q().y, LIMIT, scale(3));
}
