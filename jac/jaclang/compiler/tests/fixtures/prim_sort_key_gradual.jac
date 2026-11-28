"""Gradual sort-key returns must refuse objects, never pointer-sort (#9158).

A lambda whose return is annotated `any` slips the checker's call
overloads, so only the native lane can refuse an object-returning key.
`emit_sort` resolves the key's semantic return type, finds it gradual,
and the erased LLVM type decides -- and an object lowers to bare `i8*`,
the same type as raw string data. That lane is closed: a gradual key is a
compile error (E5092) instead of reaching strcmp.
"""
node Gthing {
    has name: str = "";
}

def grad_obj_na -> dict[str, str] {
    things: list[Gthing] = [Gthing(name="b2"), Gthing(name="a9")];
    by_grad: list[Gthing] = sorted(things, key=lambda (t: Gthing) -> any { t; });
    return {"g0": by_grad[0].name};
}
