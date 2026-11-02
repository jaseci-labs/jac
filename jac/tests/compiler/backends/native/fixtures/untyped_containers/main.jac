"""Fixture: an imported bare-frozenset global and `or {}` over a dict read."""

import from defs { Tok, is_op, is_name, OPS }

obj Holder {
    has d: dict[str, dict[str, int]] = {};
}

def values(h: Holder, k: str) -> dict[str, int] {
    return h.d.get(k) or {};
}

def has_key(h: Holder, k: str, j: str) -> bool {
    return j in (h.d.get(k) or {});
}

with entry {
    print(is_op(Tok.A), is_op(Tok.B), is_name("x"), is_name("q"), Tok.B in OPS);
    h = Holder();
    h.d["a"] = {"b": 2};
    print(len(values(h, "a")), len(values(h, "z")));
    print(has_key(h, "a", "b"), has_key(h, "z", "b"));
}
