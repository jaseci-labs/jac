"""Container element-type inference congruence (jac#7967 N5).

Every function here comes in a pair: one form writes the idiomatic untyped
local (`x = [];` / `x = [1, 2, 3];`), the other writes the same program with
the element annotation spelled out (`x: list[int] = [];`). Adding or omitting
the annotation must not change the answer -- the native backend has to take
the checker's inferred element type rather than re-deriving one from the first
element's LLVM type or falling back to tagged `any` storage.

The enum pair is the case jac#7967 hit: an untyped list of enum members infers
`list[Color.BLUE | Color.GREEN | Color.RED]`, a union of enum-member types the
backend used to lower to boxed storage while enum constants stayed unboxed.

`typed_float_from_int_literal` pins the mirror-image defect on the annotated
path: `list[float]` whose first element is an int literal must lower to f64
element storage, not to the i64 the first element happens to lower to.
"""

obj Box {
    has n: int = 0;
}

enum Color { RED = 1, GREEN = 2, BLUE = 3 }

def untyped_field_cmp -> int {
    b = Box(n=2);
    x = [];
    x.append(1);
    x.append(2);
    if x[1] == b.n {
        return 1;
    }
    return 0;
}

def typed_field_cmp -> int {
    b = Box(n=2);
    x: list[int] = [];
    x.append(1);
    x.append(2);
    if x[1] == b.n {
        return 1;
    }
    return 0;
}

def untyped_iter_sum -> int {
    x = [];
    x.append(10);
    x.append(20);
    x.append(30);
    t = 0;
    for v in x {
        t += v;
    }
    return t;
}

def typed_iter_sum -> int {
    x: list[int] = [];
    x.append(10);
    x.append(20);
    x.append(30);
    t = 0;
    for v in x {
        t += v;
    }
    return t;
}

def untyped_membership -> int {
    x = [];
    x.append(4);
    x.append(5);
    hit = 0;
    if 5 in x {
        hit += 1;
    }
    if 6 in x {
        hit += 10;
    }
    return hit;
}

def typed_membership -> int {
    x: list[int] = [];
    x.append(4);
    x.append(5);
    hit = 0;
    if 5 in x {
        hit += 1;
    }
    if 6 in x {
        hit += 10;
    }
    return hit;
}

def untyped_index_len -> int {
    x = [];
    x.append(7);
    x.append(9);
    return x[0] * 100 + x[1] * 10 + len(x);
}

def typed_index_len -> int {
    x: list[int] = [];
    x.append(7);
    x.append(9);
    return x[0] * 100 + x[1] * 10 + len(x);
}

def untyped_literal_sum -> int {
    x = [1, 2, 3, 4];
    t = 0;
    for v in x {
        t += v;
    }
    return t;
}

def typed_literal_sum -> int {
    x: list[int] = [1, 2, 3, 4];
    t = 0;
    for v in x {
        t += v;
    }
    return t;
}

def untyped_enum_pick -> int {
    c = [Color.RED, Color.GREEN, Color.BLUE];
    if c[1] == Color.GREEN {
        return 1;
    }
    return 0;
}

def typed_enum_pick -> int {
    c: list[Color] = [Color.RED, Color.GREEN, Color.BLUE];
    if c[1] == Color.GREEN {
        return 1;
    }
    return 0;
}

def untyped_enum_scan -> int {
    c = [Color.RED, Color.GREEN, Color.BLUE];
    hits = 0;
    for e in c {
        if e == Color.BLUE {
            hits += 1;
        }
    }
    return hits;
}

def typed_enum_scan -> int {
    c: list[Color] = [Color.RED, Color.GREEN, Color.BLUE];
    hits = 0;
    for e in c {
        if e == Color.BLUE {
            hits += 1;
        }
    }
    return hits;
}

def typed_float_from_int_literal -> int {
    x: list[float] = [1, 2.5];
    return int(x[1] * 100.0);
}

def untyped_float_from_float_literal -> int {
    x = [1.0, 2.5];
    return int(x[1] * 100.0);
}
