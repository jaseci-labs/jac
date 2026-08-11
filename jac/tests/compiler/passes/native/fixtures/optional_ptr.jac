"""Tagged pointer optionals (#7871 A).

Every `T | None` lowers through the one JacOptional rule: an {i8 tag, T}
value where tag 0 means None and, for pointer payloads, a None carries a
null payload slot that only the tag ever interprets. Construction, `is
None` narrowing, equality, truthiness, f-strings, and explicit unwrap all
flow through the tagged value; container slots hold optional elements as
jacval. On old main `str | None` was a bare nullable i8* and a None used
as a dict key or strcmp operand dereferenced NULL.
"""

obj Item {
    has name: str | None = None,
        score: int = 0;
}

def pick_name(flag: int) -> str | None {
    if flag > 0 {
        return "alpha";
    }
    return None;
}

def opt_local_str(flag: int) -> int {
    s: str | None = None;
    if flag > 0 {
        s = "beta";
    }
    if s is None {
        return -1;
    }
    return len(s);
}

def opt_param_str(s: str | None) -> int {
    if s is None {
        return -1;
    }
    return len(s);
}

def use_opt_param(flag: int) -> int {
    if flag > 0 {
        return opt_param_str("gamma");
    }
    return opt_param_str(None);
}

def eq_matrix -> int {
    a = pick_name(0);
    b = pick_name(1);
    c = 0;
    if a == None {
        c += 1;
    }
    if a == "" {
        c += 10;
    }
    if a != "alpha" {
        c += 100;
    }
    if b == "alpha" {
        c += 1000;
    }
    if a == a {
        c += 10000;
    }
    return c;
}

def field_flow -> int {
    it = Item();
    c = 0;
    if it.name is None {
        c += 1;
    }
    it.name = "delta";
    if it.name == "delta" {
        c += 10;
    }
    it.name = None;
    if it.name is None {
        c += 100;
    }
    return c;
}

def obj_opt_flow(flag: int) -> int {
    it: Item | None = None;
    if flag > 0 {
        it = Item(name="epsilon", score=7);
    }
    if it is None {
        return -1;
    }
    return it.score;
}

def truthy_flow -> int {
    c = 0;
    e: str | None = "";
    n: str | None = None;
    v: str | None = "x";
    if e {
        c += 1;
    }
    if n {
        c += 10;
    }
    if v {
        c += 100;
    }
    return c;
}

def fstr_flow -> int {
    n: str | None = None;
    v: str | None = "zeta";
    s = f"[{n}][{v}]";
    if s == "[None][zeta]" {
        return 1;
    }
    return 0;
}

def dict_key_narrowed -> int {
    d: dict[str, int] = {"a": 1};
    k: str | None = pick_name(1);
    if k is not None {
        d[k] = 5;
        return d["alpha"];
    }
    return -1;
}

def helper_after_narrow(flag: int) -> int {
    s = pick_name(flag);
    if s is not None {
        u = s.upper();
        if u == "ALPHA" {
            return 1;
        }
        return 2;
    }
    return 0;
}

def concat_after_narrow -> int {
    s = pick_name(1);
    if s is None {
        return -1;
    }
    t = "pre-" + s;
    if t == "pre-alpha" {
        return 1;
    }
    return 0;
}

def list_of_opt -> int {
    xs: list[str | None] = ["a", None, "b"];
    c = 0;
    if xs[1] is None {
        c += 1;
    }
    if xs[0] == "a" {
        c += 10;
    }
    x2 = xs[2];
    if x2 is not None and x2 == "b" {
        c += 100;
    }
    return c;
}

enum Marker { LO = 1, MID = 2, HI = 3 }

obj Cursor {
    has prev: Marker | None = None;
}

def marker_membership -> int {
    c = Cursor();
    r = 0;
    if c.prev in [Marker.LO, Marker.MID] {
        r += 1;
    }
    if c.prev not in [Marker.HI] {
        r += 10;
    }
    c.prev = Marker.MID;
    if c.prev in [Marker.LO, Marker.MID] {
        r += 100;
    }
    if c.prev not in [Marker.HI] {
        r += 1000;
    }
    return r;
}

def opt_str_membership -> int {
    s: str | None = None;
    r = 0;
    if s in ["a", "b"] {
        r += 1;
    }
    s = "b";
    if s in ["a", "b"] {
        r += 10;
    }
    return r;
}

def maybe_pair(flag: int) -> tuple[int, int] | None {
    if flag > 0 {
        return (3, 4);
    }
    return None;
}

def unpack_flow -> int {
    coords = maybe_pair(1);
    if coords is None {
        return -1;
    }
    (a, b) = coords;
    return a * 10 + b;
}

def matrix_flow -> int {
    grid: list[list[int | None]] = [[1, None], [None, 4]];
    c = 0;
    if grid[0][1] is None {
        c += 1;
    }
    v = grid[1][1];
    if v is not None and v == 4 {
        c += 10;
    }
    grid[0][1] = 7;
    w = grid[0][1];
    if w is not None and w == 7 {
        c += 100;
    }
    return c;
}
