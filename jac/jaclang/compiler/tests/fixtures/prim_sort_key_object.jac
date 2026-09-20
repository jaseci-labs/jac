"""A sort key returning a native object must be rejected at compile time.

Node/Edge/Walker values lower to bare `i8*`, the same LLVM type as raw
string data, so a native sort whose key returns an object used to be one
checker relaxation away from feeding object pointers to strcmp. Two layers
now refuse that: the call overloads reject a non-comparable key type, and
`NaIRGenPass.emit_sort` independently resolves the key's semantic return
type and reports E5092 for non-orderable returns before any comparison is
emitted. This fixture pins the user-facing contract (compile error, never
a silent pointer-ordered sort) regardless of which layer fires.
"""

node Thing {
    has name: str = "";
}

def obj_key_na -> dict {
    things: list[Thing] = [Thing()];
    by_obj: list[Thing] = sorted(things, key=lambda (t: Thing) -> Thing { t; });
    return {"t0": by_obj[0].name};
}
