"""`**` spread into a callee's `**kwargs` sink, lowered natively.

The sink dict is built at compile time: literal keywords are inserted
directly and each spread operand is merged in with an index loop over the
source dict. A spread key that names a keyword-bindable declared parameter
binds that slot at runtime instead (CPython semantics), raising TypeError
on a double binding or a required slot no spread supplies. Encoding below
lets a single i64 return prove both the arity and the actual keys.
"""

def sink(base: int, **kw: int) -> int {
    total = base + len(kw) * 100;
    if "p" in kw {
        total += 1000;
    }
    if "q" in kw {
        total += 2000;
    }
    if "r" in kw {
        total += 4000;
    }
    return total;
}

def forward_all(base: int, **kw: int) -> int {
    return sink(base, **kw);
}

def call_literal_kwargs(n: int) -> int {
    return sink(n, p=1, q=2);
}

def call_forwarded(n: int) -> int {
    return forward_all(n, p=1, r=3);
}

def call_spread_dict(n: int) -> int {
    d: dict[str, int] = {"p": 1, "q": 2, "r": 3};
    return sink(n, **d);
}

def call_spread_plus_literal(n: int) -> int {
    d: dict[str, int] = {"r": 3};
    return sink(n, q=2, **d);
}

def call_spread_empty(n: int) -> int {
    d: dict[str, int] = {};
    return sink(n, **d);
}

glob _SEQ: int = 0;

def _tick(n: int) -> int {
    _SEQ = _SEQ * 10 + n;
    return n;
}

def _mkd(tag: int) -> dict[str, int] {
    _tick(tag);
    return {"p": 1};
}

def order_spread_then_literal -> int {
    _SEQ = 0;
    sink(0, **_mkd(1), q=_tick(2));
    return _SEQ;
}

def order_literal_then_spread -> int {
    _SEQ = 0;
    sink(0, q=_tick(1), **_mkd(2));
    return _SEQ;
}

# ── Spread keys that name declared parameters: Python binding semantics ──
#
# A spread key naming a keyword-bindable declared parameter binds that slot
# (CPython semantics), raising TypeError when the slot is already bound and
# when a required slot stays unbound. Encodings keep the pre-binding wrong
# answers distinct from every expected value, so a silent regression to
# sink-diversion cannot pass.

# a in thousands, sink arity in hundreds, a diverted-"a" sink entry in ones.
def bind_probe(a: int = 0, **kw: int) -> int {
    return a * 1000 + len(kw) * 100 + ((kw["a"] if "a" in kw else 0));
}

# a (required) in tens, sink arity in ones.
def required_probe(a: int, **kw: int) -> int {
    return a * 10 + len(kw);
}

# positional pack in ten-thousands, kwonly k in hundreds, sink arity in ones.
def kwonly_probe(*args: int, k: int = 0, **kw: int) -> int {
    return len(args) * 10000 + k * 100 + len(kw);
}

def spread_binds_declared -> int {
    d: dict[str, int] = {"a": 5};
    return bind_probe(**d);
}

def spread_binds_required(n: int) -> int {
    d: dict[str, int] = {"a": n};
    return required_probe(**d);
}

def mixed_bind_and_sink(n: int) -> int {
    d: dict[str, int] = {"a": n, "z": 9};
    return bind_probe(**d);
}

def two_spread_split -> int {
    d1: dict[str, int] = {"a": 4};
    d2: dict[str, int] = {"z": 9};
    return bind_probe(**d1, **d2);
}

def kwonly_bind -> int {
    d: dict[str, int] = {"k": 7};
    return kwonly_probe(1, 2, **d);
}

# The sink parameter's own name is not keyword-bindable: it stays a sink key.
def sink_name_not_bindable -> int {
    d: dict[str, int] = {"kw": 3};
    return bind_probe(**d);
}

def collide_bound_kw -> int {
    d: dict[str, int] = {"a": 2};
    try {
        bind_probe(a=1, **d);
    } except TypeError {
        return 1;
    }
    return -1;
}

def collide_bound_pos -> int {
    d: dict[str, int] = {"a": 2};
    try {
        required_probe(7, **d);
    } except TypeError {
        return 1;
    }
    return -1;
}

def collide_two_spreads -> int {
    d1: dict[str, int] = {"a": 1};
    d2: dict[str, int] = {"a": 2};
    try {
        bind_probe(**d1, **d2);
    } except TypeError {
        return 1;
    }
    return -1;
}

def missing_required -> int {
    d: dict[str, int] = {"z": 1};
    try {
        x = required_probe(**d);
        return -x;
    } except TypeError {
        return 1;
    }
}
