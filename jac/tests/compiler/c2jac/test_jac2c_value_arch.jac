"""Cross-backend agreement for a *methodless* archetype (companion to the
#7145 Emit leg).

`is_ref_arch` (type_facts_pass.impl.jac) decides value-vs-reference semantics.
It used to do so with a syntactic heuristic -- an archetype was reference-
semantic iff it declared any method or any base class -- and everything else
was emitted as a bare by-value C struct. The stock bytecode interpreter, by
contrast, makes *every* obj instance a heap reference (Python-style), and Jac
has no value-type (`struct`) archetype keyword, so there is no source-level
value semantics for any archetype to carry. The heuristic therefore diverged
from the interpreter the moment a methodless obj was aliased and mutated: the
interpreter shared the instance while the C backend copied it (and in fact
emitted a constructor-less, non-compiling translation unit). Adding a single
method silently flipped the classification.

`is_ref_arch` now classifies from *declared* semantics: every archetype is
reference-semantic unless it carries the `@__jac_value__` marker, which c2jac
stamps on lifted C structs so a genuine C-ABI POD stays by-value across a
c2jac -> jac2c round-trip (that value POD half is proved by
test_jac2c_roundtrip.jac). `obj_value_alias.jac` is the native-Jac fixture the
old heuristic mishandled: a methodless, unmarked `Point` that is aliased,
mutated through the alias, then read back. This test pins that a native
archetype is reference-semantic on both backends, so a regression that
reintroduces a shape-based value/reference split fails loudly.
"""

import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    unit_src,
    link_and_run,
    interpreter_run
}

glob FIXTURE: str = "obj_value_alias.jac",
     CALLS: list[str] = ["run_mutate_alias"];


test "methodless archetype is emitted as a reference (pointer), not a value struct" {
    src = unit_src(FIXTURE, FIXTURE);
    # Reference archetypes emit `struct Point *` plus an rc-allocating
    # constructor; a value-classified archetype would emit a bare `struct Point`
    # with copy-on-assign. The uniform reference classification is what keeps
    # the C backend substitutable for the interpreter.
    assert "struct Point *" in src , f"Point not reference-classified:\n{src}";
    assert "Point__new" in src , f"no rc constructor for Point:\n{src}";
}


test "interpreter and jac2c agree when a methodless archetype is aliased and mutated" {
    if cc() is None {
        return;
    }
    # a = Point(); a.x = 5; b = a; b.x = 9; return a.x
    # Under reference semantics `b` aliases `a`, so the mutation through `b` is
    # visible on `a` (-> 9) on both backends. Under the old value heuristic the
    # emitted C copied on `b = a` and disagreed.
    py_out = interpreter_run([FIXTURE], FIXTURE, CALLS);
    c_out = link_and_run(emit_units(FIXTURE), CALLS);
    assert py_out == "9" , f"interpreter no longer aliases: {py_out!r}";
    assert c_out == py_out , f"jac2c {c_out!r} != interpreter {py_out!r}: methodless archetype " + "must be reference-semantic on both backends";
}
