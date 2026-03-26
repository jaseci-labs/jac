"""Test: JS-specific property access should produce portability warnings."""

def use_length_prop() -> None {
    items: list = [1, 2, 3];
    n = items.length;
    s = "hello";
    m = s.length;
}

def use_prototype_prop() -> None {
    obj MyObj {
        has x: int = 0;
    }
    p = MyObj.prototype;
}
