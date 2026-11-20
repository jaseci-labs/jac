"""A variadic parameter typed by a generic archetype's erased type parameter.

`Cell[T]` is the shape the bundled `contextvars` shim wanted (#8247): the
pack carries the *presence* of a fallback, which `(T | None) = None` cannot,
because `None` is also a legal value there. Every answer below is pinned
against CPython by running this same file on both pathways, so the precedence
ladder, the empty pack, and the multi-element pack all have to agree.
"""

obj Req {
    has ident: str = "";
}

obj Cell[T] {
    has name: str,
        `default: (T | None) = None,
        _value: (T | None) = None;

    def get(*fallback: T) -> T {
        if self._value is not None {
            return self._value;
        }
        if len(fallback) > 0 {
            return fallback[0];
        }
        if self.`default is not None {
            return self.`default;
        }
        raise LookupError(self.name);
    }

    def set(value: T) {
        self._value = value;
    }

    def count(*items: T) -> int {
        n = 0;
        for _it in items {
            n = n + 1;
        }
        return n * 10 + len(items);
    }

    def pick(idx: int, *items: T) -> T {
        return items[idx];
    }
}

glob CUR: Cell[Req] = Cell[Req]("cur"),
     FALLBACK: Cell[Req] = Cell[Req]("fallback", `default=Req(ident="ctor"));

def unset_raises -> str {
    try {
        got = CUR.get();
        return "no-raise:" + got.ident;
    } except LookupError {
        return "LookupError";
    }
}

def run_probe {
    print(unset_raises());
    print(CUR.get(Req(ident="call")).ident);
    print(FALLBACK.get().ident);
    print(FALLBACK.get(Req(ident="wins")).ident);
    CUR.set(Req(ident="first"));
    print(CUR.get().ident);
    print(CUR.get(Req(ident="ignored")).ident);
    print(CUR.count());
    print(CUR.count(Req(ident="a")));
    print(CUR.count(Req(ident="a"), Req(ident="b"), Req(ident="c")));
    print(CUR.pick(0, Req(ident="a"), Req(ident="b")).ident);
    print(CUR.pick(1, Req(ident="a"), Req(ident="b")).ident);
}

with entry {
    run_probe();
}
