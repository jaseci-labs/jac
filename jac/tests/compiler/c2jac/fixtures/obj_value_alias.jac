"""Mutate-after-alias fixture on a methodless, unmarked archetype.

`Point` is a native Jac obj with no method, no base class, and no
`@__jac_value__` marker, so `is_ref_arch` classifies it reference-semantic --
matching the stock bytecode interpreter, which makes every obj instance a heap
reference.

`run_mutate_alias` aliases (`b = a`), mutates through the alias (`b.x = 9`),
then reads the source (`a.x`). Under reference semantics both the interpreter
and the jac2c-emitted C see the mutation (-> 9). The old shape-based heuristic
classified this methodless obj value-semantic and diverged: the emitted C
copied on `b = a` (and in fact failed to compile at all). This fixture pins the
agreement; see test_jac2c_value_arch.jac.
"""

obj Point {
    has x: int = 0;
}

def run_mutate_alias -> int {
    a = Point();
    a.x = 5;
    b = a;
    b.x = 9;
    return a.x;
}
