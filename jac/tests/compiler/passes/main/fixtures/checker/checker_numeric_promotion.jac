"""Test numeric type promotion for arithmetic operations."""

with entry {
    # int + int = int
    a: int = 1 + 2;

    # int + float = float (int promoted to float)
    b: float = 1 + 2.0;

    # float + int = float
    c: float = 1.0 + 2;

    # float + float = float
    d: float = 1.0 + 2.0;

    # int / int = float (division always returns float)
    e: float = 4 / 2;

    # int - float = float
    f: float = 5 - 2.5;

    # float * int = float
    g: float = 2.5 * 4;

    # int ** float = float
    h: float = 2 ** 0.5;

    # int // int = int
    i: int = 7 // 2;

    # int // float = float
    j: float = 7 // 2.0;

    # int % float = float
    k: float = 7 % 2.5;

    # These should produce errors (assigning float result to int)
    err1: int = 1 + 2.0;  # <-- Error: float cannot be assigned to int
    err2: int = 4 / 2;    # <-- Error: division always returns float
    err3: int = 2.0 * 3;  # <-- Error: float cannot be assigned to int
}
