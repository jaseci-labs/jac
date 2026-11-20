"""`...` as a value: boxed, compared, printed and passed like any other object."""

def marker -> object {
    return ...;
}

def pick(flag: bool) -> any {
    if flag {
        return ...;
    }
    return None;
}

def ident(v: object) -> object {
    return v;
}

def placeholder {
    ...;
}

def describe(v: object) -> str {
    if v is ... {
        return "ellipsis";
    }
    if v is None {
        return "none";
    }
    return "other";
}

glob x: object = ...;

with entry {
    print(x);
    print(...);
    print(str(...), repr(...), str(x), repr(x));
    print(f"{x}|{...}|{x!r}");
    print(x is ..., x is not ..., x == ..., x != ...);
    print(... is x, ... == x, ... is ..., ... == ...);
    print(x is None, x == None, x is not None);
}

glob n: object = None;

with entry {
    print(n is ..., n == ..., n is not ...);
}

glob i: object = 5;

with entry {
    print(i is ..., i == ..., i != ...);
    print(0 == ..., 0 != ...);
    print(marker() is ..., pick(True) is ..., pick(False) is ...);
    print(ident(...) is ..., describe(...), describe(None), describe(3));
    print(not x, not not x);
    if x {
        print("truthy");
    }
    placeholder();
}

glob items: list[any] = [..., None, 1];

with entry {
    print(items);
    print(isinstance(x, type(...)), isinstance(n, type(...)), isinstance(i, type(...)));
}
