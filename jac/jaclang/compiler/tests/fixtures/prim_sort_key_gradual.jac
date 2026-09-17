"""Gradual sort-key returns must refuse objects, never pointer-sort (#9158).

A lambda whose return is annotated `any` slips the checker's call
overloads, so only the native lane can refuse an object-returning key.
`emit_sort` resolves the key's semantic return type, finds it gradual,
and the erased LLVM type decides -- and an object lowers to bare `i8*`,
the same type as raw string data. That lane is closed: gradual keys are
rejected (E5092, the function demotes to its Python implementation)
instead of reaching strcmp. A semantic `-> str` key in the same module
stays natively lowered as the positive control.
"""
node Gthing {
    has name: str = "";
}

def grad_obj_na -> dict[str, str] {
    things: list[Gthing] = [Gthing(name="b2"), Gthing(name="a9")];
    by_grad: list[Gthing] = sorted(things, key=lambda (t: Gthing) -> any { t; });
    return {"g0": by_grad[0].name};
}

def grad_str_na -> dict[str, str] {
    things: list[Gthing] = [Gthing(name="b2"), Gthing(name="a9")];
    by_name: list[Gthing] = sorted(things, key=lambda (t: Gthing) -> str { t.name; });
    return {"s0": by_name[0].name};
}
