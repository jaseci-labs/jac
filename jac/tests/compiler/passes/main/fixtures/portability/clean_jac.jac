"""Test: Clean Jac code using common primitives should produce no portability warnings."""

def proper_print() -> None {
    print("hello");
}

def proper_math() -> None {
    x = abs(-5);
    y = round(3.5);
    z = min(1, 2);
    w = max(3, 4);
    p = pow(2, 10);
}

def proper_list_ops() -> None {
    items: list = [1, 2, 3];
    items.append(4);
    items.insert(0, 0);
    items.pop(0);
    n = len(items);
    found = 2 in items;
}

def proper_string_ops() -> None {
    s = "hello world";
    c = s[0];
    sub = s[0:5];
    stripped = s.strip();
    n = len(s);
}

def proper_dict_ops() -> None {
    d: dict = {"a": 1};
    k = d.keys();
    v = d.values();
    i = d.items();
    has_it = "a" in d;
}
