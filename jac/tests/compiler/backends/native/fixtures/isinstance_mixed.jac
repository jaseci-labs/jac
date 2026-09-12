"""isinstance over tuples mixing builtin and archetype targets.

`int` resolves to JacVal tag compares while `Foo` / `Lone` resolve to vtable
identity, so the check lowers as a guarded disjunction on one boxed operand:
tag compares for the builtin arms, and (only when the tag says the payload is
an object pointer) a vtable compare against every type whose MRO contains an
archetype arm. `Sub(Foo)` must match the `Foo` arm; `Other` must not. `Lone`
has no hierarchy at all, so naming it in an isinstance tuple is what forces
its vtable to materialize.
"""

obj Foo {
    has v: int = 0;
}

obj Sub(Foo) {
    has w: int = 0;
}

obj Other {
    has z: int = 0;
}

obj Lone {
    has q: int = 0;
}

obj StringBox {
    has value: str;
}

def typed_string_check(value: str) -> bool {
    return isinstance(value, str);
}

def optional_string_check(value: str | None) -> bool {
    return isinstance(value, str);
}

def chk_string_representations -> int {
    box = StringBox(value="hello");
    local = box.value;
    result = 0;
    if isinstance("", str) {
        result += 1;
    }
    if isinstance(box.value, str) {
        result += 2;
    }
    if isinstance(local, (str, Other)) {
        result += 4;
    }
    if typed_string_check(local) {
        result += 8;
    }
    if optional_string_check(local) {
        result += 16;
    }
    if not optional_string_check(None) {
        result += 32;
    }
    if not isinstance(Other(), str) {
        result += 64;
    }
    return result;
}

def chk_int_foo(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = 7;
    } elif k == 1 {
        x = "s";
    } elif k == 2 {
        x = Foo(v=1);
    } elif k == 3 {
        x = Sub(w=2);
    } elif k == 4 {
        x = Other(z=3);
    } elif k == 5 {
        x = True;
    } else {
        x = None;
    }
    if isinstance(x, (int, Foo)) {
        return 1;
    }
    return 0;
}

def chk_str_other(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = "hello";
    } elif k == 1 {
        x = Other(z=5);
    } else {
        x = Foo(v=9);
    }
    if isinstance(x, (str, Other)) {
        return 1;
    }
    return 0;
}

def chk_lone(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = Lone(q=1);
    } else {
        x = 3.5;
    }
    if isinstance(x, (float, Lone)) {
        return 1;
    }
    return 0;
}

def chk_typed_operand -> int {
    f = Sub(w=4);
    if isinstance(f, (int, Foo)) {
        return 1;
    }
    return 0;
}
