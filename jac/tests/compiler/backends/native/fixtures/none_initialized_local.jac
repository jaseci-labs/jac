"""Locals first bound to None and later to a value keep the value's type."""
obj Cg {
    has cls: str;
}

def kind(v: object) -> str {
    if v is None {
        return "none";
    } elif isinstance(v, Cg) {
        return "cg:" + v.cls;
    } elif isinstance(v, bool) {
        return "bool";
    } elif isinstance(v, int) {
        return "int";
    } elif isinstance(v, str) {
        return "str";
    } elif isinstance(v, list) {
        return "list";
    } elif isinstance(v, dict) {
        return "dict";
    }
    return "other";
}

def pick_int(f: bool) -> int {
    n = None;
    if f {
        n = 42;
    }
    return n if n is not None else -1;
}

def pick_str(f: bool) -> str {
    s = None;
    if f {
        s = "hi" + "!";
    }
    return s if s is not None else "none";
}

def pick_list(f: bool) -> int {
    xs = None;
    if f {
        xs = [1, 2, 3];
    }
    return len(xs) if xs is not None else -1;
}

def pick_obj_twice(f: bool) -> list[any] {
    c = None;
    if f {
        c = Cg(cls="a");
        c = Cg(cls="b");
    }
    return [c];
}

def boxed_after_none(flag: bool) -> list[any] {
    value = None;
    if flag {
        value = Cg(cls="Constant");
    }
    return ["x", value];
}

def stays_none -> list[any] {
    c = None;
    return [c, 1];
}

with entry {
    print(
        pick_int(True),
        pick_int(False),
        pick_str(True),
        pick_str(False),
        pick_list(True),
        pick_list(False)
    );
    print(
        kind(pick_obj_twice(True)[0]),
        kind(pick_obj_twice(False)[0]),
        kind(stays_none()[0])
    );
    print(kind(boxed_after_none(True)[1]), kind(boxed_after_none(False)[1]));
}
