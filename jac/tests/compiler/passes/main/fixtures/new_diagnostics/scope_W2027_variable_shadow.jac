"""Fixture for W2027: Variable shadows outer scope variable."""

glob x: int = 10;

def foo() -> None {
    x = 20;  # <-- Warning W2027: shadows module-level x
    print(x);
}

def bar() -> None {
    for x in [1, 2, 3] {  # <-- Warning W2027: shadows module-level x
        print(x);
    }
}

def no_shadow() -> None {
    y = 30;  # <-- Ok: no outer 'y'
    print(y);
}
