"""Coercion routing at optional-typed call and assignment seams (N2).

`_coerce_type` already implements optional wrapping and checked
unwrapping. Three use sites did not route through it, and the functions
that pin them are:

1. `arg_unwrap_container`, `arg_unwrap_str`, `arg_join_unwrap` -- method
   call arguments on the primitive dispatch path, where a narrowed
   `T | None` argument used to reach an emitter that expects the payload;
2. `opt_list_receiver`, `opt_list_receiver_guarded` -- method receivers,
   i.e. the idiomatic `x: list[int] | None = None; x = []; x.append(1);`
   shape;
3. `unpack_wrap`, `unpack_unwrap` -- tuple-unpack assignment stores, where
   a target's declared type needs a wrap or an unwrap.

The remaining functions cover neighbouring coercions that already worked
and are kept as native-vs-sv congruence guards: `arg_wrap`,
`arg_wrap_none` and `arg_unwrap` call methods on a user obj, whose
arguments are coerced against the callee's declared LLVM signature, and
`arg_wrap_elem` leans on the list emitter's own element-type coercion.

Every function returns an int so the native result can be compared
against the same source run through the sv/bytecode pathway.
"""

obj Sink {
    has base: int = 0;

    def take_opt(v: int | None) -> int {
        if v is None {
            return -1;
        }
        return self.base + v;
    }

    def take_plain(v: int) -> int {
        return self.base + v * 2;
    }
}

def arg_wrap(n: int) -> int {
    s = Sink(base=10);
    return s.take_opt(n);
}

def arg_wrap_none -> int {
    s = Sink(base=10);
    return s.take_opt(None);
}

def arg_unwrap(n: int) -> int {
    s = Sink(base=10);
    o: int | None = None;
    if n > 0 {
        o = n;
    }
    if o is None {
        return -1;
    }
    return s.take_plain(o);
}

def arg_unwrap_container(flag: int) -> int {
    src: list[int] | None = None;
    if flag > 0 {
        src = [4, 5, 6];
    }
    out: list[int] = [1];
    if src is None {
        return len(out);
    }
    out.extend(src);
    return len(out) * 100 + out[1] * 10 + out[3];
}

def arg_unwrap_str(flag: int) -> int {
    t: str | None = None;
    if flag > 0 {
        t = "abc";
    }
    if t is None {
        return -1;
    }
    s = "abcdef";
    if s.startswith(t) {
        return 1;
    }
    return 0;
}

def arg_join_unwrap(flag: int) -> int {
    parts: list[str] | None = None;
    if flag > 0 {
        parts = ["ab", "cd"];
    }
    if parts is None {
        return -1;
    }
    return len("-".join(parts));
}

def arg_wrap_elem(n: int) -> int {
    xs: list[str | None] = [];
    t: str = "abc";
    xs.append(t);
    xs.append(None);
    v = xs[0];
    if v is None {
        return -1;
    }
    if xs[1] is not None {
        return -2;
    }
    return len(v) * 10 + n;
}

def opt_list_receiver(n: int) -> int {
    x: list[int] | None = None;
    x = [];
    x.append(1);
    x.append(n);
    if x is None {
        return -1;
    }
    y: list[int] = x;
    return len(y) * 100 + y[0] * 10 + y[1];
}

def opt_list_receiver_guarded(flag: int) -> int {
    x: list[int] | None = None;
    if flag > 0 {
        x = [];
    }
    if x is None {
        return -1;
    }
    x.append(7);
    x.append(flag);
    y: list[int] = x;
    return y[0] * 10 + y[1];
}

def unpack_wrap(n: int) -> int {
    a: int | None = None;
    b: int | None = None;
    (a, b) = (n, n + 1);
    if a is None or b is None {
        return -1;
    }
    return a * 10 + b;
}

def unpack_unwrap(n: int) -> int {
    a: int | None = n;
    b: int | None = n + 1;
    if a is None or b is None {
        return -1;
    }
    p: int = 0;
    q: int = 0;
    (p, q) = (a, b);
    return p * 10 + q;
}
