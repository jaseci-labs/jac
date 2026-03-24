"""Test: JS-specific keywords should produce portability warnings."""

def use_undefined() -> None {
    x = undefined;
}

def use_typeof() -> None {
    t = typeof(x);
}

def use_void() -> None {
    v = void;
}
