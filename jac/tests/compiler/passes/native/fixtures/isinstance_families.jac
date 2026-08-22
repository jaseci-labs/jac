"""isinstance arms that carry no JacVal tag, reduce from an ABC, or arrive as values.

Three shapes the tag-compare machinery alone cannot answer are exercised here.

`tuple`, `bytes` and `bytearray` have no JacVal tag: a native tuple is an
unboxed literal struct and the other two are pointers to their own runtime
structs, so none can be reached by comparing a boxed operand's tag. Each is
instead decided from the operand's LLVM type, which is known at the check --
so `isinstance(t, (list, tuple))` on a tuple is a constant `True` and the same
check on a list answers through the `list` arm's tag.

`Sequence` is a `collections.abc` class no native unit can host. It reduces to
the finite set of native shapes that inhabit it, so a list, a tuple and a str
all answer `True` while an int and an archetype answer `False`.

`isinstance(x, types)` with `types` a parameter has its arms arrive as values.
Both the fixed-arity spelling and the variadic one are covered: the first
unrolls its arms, the second lowers to a native sequence whose length is a
runtime value, so the compare runs as a loop.
"""

obj Base {
    has v: int = 0;
}

obj Foo(Base) {
    has w: int = 0;
}

obj Bar(Base) {
    has z: int = 0;
}

obj Baz(Base) {
    has q: int = 0;
}

def chk_list_or_tuple(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = [1, 2];
    } elif k == 1 {
        x = "s";
    } elif k == 2 {
        x = 3;
    } else {
        x = Foo(w=1);
    }
    if isinstance(x, (list, tuple)) {
        return 1;
    }
    return 0;
}

def chk_tuple_operand -> int {
    t = (1, 2, );
    if isinstance(t, (list, tuple)) {
        return 1;
    }
    return 0;
}

def chk_tuple_bare -> int {
    t = (1, 2, 3, );
    if isinstance(t, tuple) {
        return 1;
    }
    return 0;
}

def chk_list_is_not_tuple -> int {
    v = [1, 2];
    if isinstance(v, tuple) {
        return 1;
    }
    return 0;
}

def chk_bytes_operand -> int {
    b = b"abc";
    if isinstance(b, bytes) {
        return 1;
    }
    return 0;
}

def chk_str_is_not_bytes -> int {
    s = "abc";
    if isinstance(s, bytes) {
        return 1;
    }
    return 0;
}

def chk_sequence(k: int) -> int {
    x: any = [1, 2];
    if k == 1 {
        x = 5;
    } elif k == 2 {
        x = "ab";
    } elif k == 3 {
        x = {1: 2};
    } elif k == 4 {
        x = Foo(w=1);
    }
    if isinstance(x, Sequence) {
        return 1;
    }
    return 0;
}

def chk_sequence_typed(k: int) -> int {
    if k == 0 {
        s: str = "ab";
        return 1 if isinstance(s, Sequence) else 0;
    }
    if k == 1 {
        v: list[int] = [1, 2];
        return 1 if isinstance(v, Sequence) else 0;
    }
    t = (1, 2, );
    return 1 if isinstance(t, Sequence) else 0;
}

def chk_mapping(k: int) -> int {
    x: any = {1: 2};
    if k == 1 {
        x = [1, 2];
    }
    if isinstance(x, Mapping) {
        return 1;
    }
    return 0;
}

def of_types_fixed(x: Base, types: tuple[type[Base], type[Base]]) -> int {
    if isinstance(x, types) {
        return 1;
    }
    return 0;
}

def of_types_variadic(x: Base, types: tuple[type[Base], ...]) -> int {
    if isinstance(x, types) {
        return 1;
    }
    return 0;
}

def pick(k: int) -> Base {
    if k == 1 {
        return Bar(z=2);
    }
    if k == 2 {
        return Baz(q=3);
    }
    return Foo(w=1);
}

def chk_types_fixed(k: int) -> int {
    return of_types_fixed(pick(k), (Foo, Bar, ));
}

def chk_types_variadic(k: int) -> int {
    return of_types_variadic(pick(k), (Foo, Bar, ));
}

def chk_types_variadic_one(k: int) -> int {
    return of_types_variadic(pick(k), (Baz, ));
}

def chk_types_variadic_three(k: int) -> int {
    return of_types_variadic(pick(k), (Foo, Bar, Baz, ));
}

obj Stmt {
    has ident: int = 0,
        up: (Stmt | None) = None,
        body: (list[Stmt] | None) = None;
}

def find_parent_of_types(nd: Stmt, types: tuple[type[Stmt], ...]) -> int {
    cur = nd.up;
    depth = 0;
    while cur {
        depth += 1;
        if isinstance(cur, types) {
            return depth;
        }
        cur = cur?.up;
    }
    return 0;
}

def link_sequential(body: (Sequence | None)) -> int {
    if body is not None and isinstance(body, Sequence) {
        return len(list(body));
    }
    return -1;
}

def chk_parent_walk -> int {
    top = Stmt(ident=7);
    mid = Stmt(ident=8, up=top);
    leaf = Stmt(ident=9, up=mid);
    return find_parent_of_types(leaf, (Stmt, ));
}

def chk_link_sequential(k: int) -> int {
    holder = Stmt(ident=1, body=[Stmt(ident=2), Stmt(ident=3)]);
    if k == 1 {
        holder.body = None;
    }
    return link_sequential(holder.body);
}
